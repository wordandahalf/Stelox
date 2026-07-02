const std = @import("std");
const x86 = std.Target.x86;

// todo: probably don't need this, all x86_64 chips likely have these
const disabled_features = x86.featureSet(&[_]x86.Feature{ .mmx, .sse, .sse2, .avx, .avx2 });
const enabled_features = x86.featureSet(&[_]x86.Feature{.soft_float});

const bootloader_target = std.Target.Query{
    .cpu_arch = .x86_64,
    .os_tag = .uefi,
    .abi = .gnu,
    // .cpu_features_sub = disabled_features,
    // .cpu_features_add = enabled_features
};

const kernel_target = std.Target.Query{
    .cpu_arch = .x86_64,
    .os_tag = .freestanding,
    .abi = .none,
    // .cpu_features_sub = disabled_features,
    // .cpu_features_add = enabled_features
};

pub fn build(b: *std.Build) void {
    const mode = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const lib_mod = b.addModule("lib", .{
        .root_source_file = b.path("lib/root.zig"),
    });
    lib_mod.addImport("lib", lib_mod);

    const bootloader_mod = b.addModule("bootloader", .{
        .root_source_file = b.path("src/boot/main.zig"),
        .target = b.resolveTargetQuery(bootloader_target),
        .optimize = mode,
    });
    bootloader_mod.addImport("lib", lib_mod);

    const kernel_mod = b.addModule("kernel", .{
        .root_source_file = b.path("src/kernel/main.zig"),
        .target = b.resolveTargetQuery(kernel_target),
        .optimize = mode,
        .code_model = .kernel,
    });
    kernel_mod.addImport("lib", lib_mod);

    const bootloader_exe = b.addExecutable(.{
        .name = "bootx64",
        .root_module = bootloader_mod,
    });

    b.installArtifact(bootloader_exe);

    const kernel_exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = kernel_mod,
    });

    kernel_exe.use_llvm = true;
    kernel_exe.use_lld = true;
    kernel_exe.setLinkerScript(b.path("src/kernel/linker.ld"));
    b.installArtifact(kernel_exe);

    var bootloader_step = b.step("bootloader", "Build bootloader");
    bootloader_step.dependOn(&bootloader_exe.step);

    var kernel_step = b.step("kernel", "Build kernel");
    kernel_step.dependOn(&kernel_exe.step);

    var create_image = b.addSystemCommand(&.{"./utils/make-fat.sh"});
    create_image.addArg("-i");
    create_image.addArtifactArg(bootloader_exe);
    create_image.addArg("-o");
    const created_image = create_image.addOutputFileArg("bootloader.fat");

    var create_iso = b.addSystemCommand(&.{"xorriso"});
    create_iso.addArgs(&.{ "-as", "mkisofs", "-f", "-e", "efi/boot/efi.fat", "-no-emul-boot" });
    create_iso.addArg("-o");
    const created_iso = create_iso.addOutputFileArg("stelox.iso");
    create_iso.addArg("-graft-points");
    create_iso.addPrefixedFileArg("efi/boot/efi.fat=", created_image);
    create_iso.addPrefixedArtifactArg("kernel/kernel64.elf=", kernel_exe);

    const installed_file = b.addInstallFileWithDir(created_iso, .{ .custom = "." }, "stelox.iso");
    b.getInstallStep().dependOn(&installed_file.step);

    const run_iso = b.addSystemCommand(&.{"qemu-system-x86_64"});
    run_iso.addArgs(&.{ "-drive", "if=pflash,format=raw,file=OVMF.fd" });
    run_iso.addArg("-cdrom");
    run_iso.addFileArg(created_iso);
    run_iso.addArgs(&.{ "-net", "none" });
    run_iso.addArgs(&.{ "-serial", "stdio" });
    run_iso.addArgs(&.{ "-d", "guest_errors" });
    run_iso.addArgs(&.{ "-m", "512M" });

    const qemu = b.step("qemu", "Runs the OS in QEMU");
    qemu.dependOn(&run_iso.step);
}
