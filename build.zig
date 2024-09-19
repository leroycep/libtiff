const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const enable_libdeflate = b.option(bool, "libdeflate", "enable using libdeflate (default: false)") orelse false;
    const enable_zip = b.option(bool, "zip", "enable zip (deflate) compression (default: true)") orelse true;
    const enable_lzma = b.option(bool, "lzma", "enable lzma compression; requires liblzma to be installed (default: false)") orelse false;
    const enable_zstd = b.option(bool, "zstd", "enable zstd compression (default: true)") orelse true;

    // tif_config_h
    const tif_config_h = b.addConfigHeader(.{ .style = .{ .autoconf = b.path("libtiff/tif_config.h.in") } }, .{
        .HAVE_UNISTD_H = 1,
        .HAVE_FCNTL_H = 1,

        .CCITT_SUPPORT = null,
        .CHECK_JPEG_YCBCR_SUBSAMPLING = null,
        .CHUNKY_STRIP_READ_SUPPORT = null,
        .CXX_SUPPORT = null,
        .DEFER_STRILE_LOAD = null,
        .HAVE_ASSERT_H = null,
        .HAVE_DECL_OPTARG = null,
        .HAVE_FSEEKO = null,
        .HAVE_GETOPT = null,
        .HAVE_GLUT_GLUT_H = null,
        .HAVE_GL_GLUT_H = null,
        .HAVE_GL_GLU_H = null,
        .HAVE_GL_GL_H = null,
        .HAVE_IO_H = null,
        .HAVE_JBG_NEWLEN = null,
        .HAVE_MMAP = null,
        .HAVE_OPENGL_GLU_H = null,
        .HAVE_OPENGL_GL_H = null,
        .HAVE_SETMODE = null,
        .HAVE_SNPRINTF = null,
        .HAVE_STRINGS_H = null,
        .HAVE_SYS_TYPES_H = null,
        .JPEG_DUAL_MODE_8_12 = null,
        .LERC_SUPPORT = null,
        .LIBJPEG_12_PATH = null,
        .PACKAGE = null,
        .PACKAGE_BUGREPORT = null,
        .PACKAGE_NAME = null,
        .PACKAGE_TARNAME = null,
        .PACKAGE_URL = null,
        .STRIP_SIZE_DEFAULT = null,
        .TIFF_MAX_DIR_COUNT = null,
        .WEBP_SUPPORT = null,
        .ZSTD_SUPPORT = null,
        ._FILE_OFFSET_BITS = null,
        ._LARGEFILE_SOURCE = null,
        ._LARGE_FILES = null,
        .WORDS_BIGENDIAN = null,
    });
    try tif_config_h.values.put("SIZEOF_SIZE_T", switch (target.result.ptrBitWidth()) {
        32 => .{ .int = 4 },
        64 => .{ .int = 8 },
        else => return error.UnsupportedPointerBitWidth,
    });
    try tif_config_h.values.put("USE_WIN32_FILEIO", switch (target.result.os.tag) {
        .windows => .defined,
        else => .undef,
    });
    try tif_config_h.values.put("LZMA_SUPPORT", if (enable_lzma) .{ .int = 1 } else .undef);
    try tif_config_h.values.put("ZSTD_SUPPORT", if (enable_zstd) .{ .int = 1 } else .undef);

    // "tiffconf.h": non-UNIX configuration definitions
    const tiffconf_h = b.addConfigHeader(.{ .style = .{ .autoconf = b.path("libtiff/tiffconf.h.in") } }, .{
        .TIFF_INT16_T = .int16_t,
        .TIFF_INT32_T = .int32_t,
        .TIFF_INT64_T = .int64_t,
        .TIFF_INT8_T = .int8_t,
        .TIFF_UINT16_T = .uint16_t,
        .TIFF_UINT32_T = .uint32_t,
        .TIFF_UINT64_T = .uint64_t,
        .TIFF_UINT8_T = .uint8_t,
        .HAVE_IEEEFP = 1,

        .PACKBITS_SUPPORT = 1,

        // .HOST_FILLORDER = false,
        .HOST_BIGENDIAN = null,
        .CCITT_SUPPORT = null,
        .JPEG_SUPPORT = null,
        .JBIG_SUPPORT = null,
        .LERC_SUPPORT = null,
        .LOGLUV_SUPPORT = null,
        .LZW_SUPPORT = null,
        .NEXT_SUPPORT = null,
        .OJPEG_SUPPORT = null,
        .PIXARLOG_SUPPORT = null,
        .THUNDER_SUPPORT = null,
        // .LIBDEFLATE_SUPPORT = null,
        .STRIPCHOP_DEFAULT = null,
        .SUBIFD_SUPPORT = null,
        .DEFAULT_EXTRASAMPLE_AS_ALPHA = null,
        .CHECK_JPEG_YCBCR_SUBSAMPLING = null,
        .MDI_SUPPORT = null,
    });

    // Required to specify a identifier during runtime
    try tiffconf_h.values.put("TIFF_SSIZE_T", switch (target.result.ptrBitWidth()) {
        32 => .{ .ident = "int32_t" },
        64 => .{ .ident = "int64_t" },
        else => return error.UnsupportedPointerBitWidth,
    });
    try tiffconf_h.values.put("LIBDEFLATE_SUPPORT", if (enable_libdeflate) .{ .int = 1 } else .undef);
    try tiffconf_h.values.put("ZIP_SUPPORT", if (enable_zip) .{ .int = 1 } else .undef);

    // tiff_port library
    const libport_config_h = b.addConfigHeader(.{ .style = .{ .autoconf = b.path("./port/libport_config.h.in") } }, .{
        .HAVE_GETOPT = null,
        .HAVE_UNISTD_H = 1,
    });
    const tiff_port = b.addStaticLibrary(.{
        .name = "port",
        .target = b.graph.host,
        .optimize = .Debug,
    });
    tiff_port.installConfigHeader(libport_config_h);
    tiff_port.addCSourceFile(.{ .file = b.path("./port/dummy.c") });
    tiff_port.installHeader(b.path("./port/libport.h"), "libport.h");

    // "make g3 states" executable
    const mkg3states = b.addExecutable(.{
        .name = "mkg3states",
        .target = b.graph.host,
    });
    mkg3states.addConfigHeader(tif_config_h);
    mkg3states.addConfigHeader(tiffconf_h);
    mkg3states.addCSourceFile(.{ .file = b.path("./libtiff/mkg3states.c") });
    mkg3states.linkLibrary(tiff_port);
    mkg3states.linkLibC();

    const generate_tif_fax3sm_c = b.addRunArtifact(mkg3states);
    generate_tif_fax3sm_c.addArgs(&.{ "-c", "const" });
    const tif_fax3sm_c = generate_tif_fax3sm_c.addOutputFileArg("tif_fax3sm.c");

    // see file ./VERSION
    const VERSION_STRING = "4.7.0";
    const version = try std.SemanticVersion.parse(VERSION_STRING);

    // see file ./RELEASE-DATE
    const @"RELEASE-DATE_STRING" = "20240911";
    const @"RELEASE-DATE" = try std.fmt.parseInt(i64, @"RELEASE-DATE_STRING", 10);

    // version config header
    const tiffvers_h = b.addConfigHeader(.{ .include_path = "tiffvers.h", .style = .{ .cmake = b.path("libtiff/tiffvers.h.cmake.in") } }, .{
        .LIBTIFF_VERSION = VERSION_STRING,
        .LIBTIFF_RELEASE_DATE = @"RELEASE-DATE",
        .LIBTIFF_MAJOR_VERSION = @as(i64, @intCast(version.major)),
        .LIBTIFF_MINOR_VERSION = @as(i64, @intCast(version.minor)),
        .LIBTIFF_MICRO_VERSION = @as(i64, @intCast(version.patch)),
    });

    // libtiff itself
    const libtiff = b.addStaticLibrary(.{
        .name = "tiff",
        .target = target,
        .optimize = optimize,
    });

    libtiff.addConfigHeader(tiffvers_h);
    libtiff.addConfigHeader(tiffconf_h);
    libtiff.addConfigHeader(tif_config_h);

    libtiff.installConfigHeader(tiffconf_h);
    libtiff.installConfigHeader(tif_config_h);
    libtiff.installConfigHeader(tiffvers_h);
    libtiff.installHeadersDirectory(b.path("libtiff"), "", .{});

    libtiff.addIncludePath(b.path("libtiff"));
    libtiff.addCSourceFile(.{ .file = tif_fax3sm_c });
    libtiff.addCSourceFiles(.{
        .files = &.{
            "libtiff/tif_aux.c",
            "libtiff/tif_close.c",
            "libtiff/tif_codec.c",
            "libtiff/tif_color.c",
            "libtiff/tif_compress.c",
            "libtiff/tif_dir.c",
            "libtiff/tif_dirinfo.c",
            "libtiff/tif_dirread.c",
            "libtiff/tif_dirwrite.c",
            "libtiff/tif_dumpmode.c",
            "libtiff/tif_error.c",
            "libtiff/tif_extension.c",
            "libtiff/tif_fax3.c",
            "libtiff/tif_fax3sm.c",
            "libtiff/tif_flush.c",
            "libtiff/tif_getimage.c",
            "libtiff/tif_hash_set.c",
            "libtiff/tif_luv.c",
            "libtiff/tif_lzw.c",
            "libtiff/tif_next.c",
            "libtiff/tif_open.c",
            "libtiff/tif_packbits.c",
            "libtiff/tif_predict.c",
            "libtiff/tif_print.c",
            "libtiff/tif_read.c",
            "libtiff/tif_strip.c",
            "libtiff/tif_swab.c",
            "libtiff/tif_tile.c",
            "libtiff/tif_version.c",
            "libtiff/tif_warning.c",
            "libtiff/tif_write.c",
        },
        .flags = &.{},
    });
    libtiff.linkLibC();

    // TODO:
    // if (enable_jbig) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_jbig.c") });
    // if (enable_jpeg) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_jpeg.c") });
    // if (enable_jpeg_12) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_jpeg_12.c") });
    // if (enable_lerc) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_lerc.c") });
    // if (enable_ojpeg) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_ojpeg.c") });
    // if (enable_pixarlog) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_pixarlog.c") });
    // if (enable_thunder) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_thunder.c") });
    // if (enable_webp) libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_webp.c") });

    if (enable_zstd) {
        libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_zstd.c") });

        if (b.lazyDependency("zstd", .{
            .target = target,
            .optimize = optimize,
        })) |zstd| {
            libtiff.linkLibrary(zstd.artifact("zstd"));
        }
    }

    if (enable_lzma) {
        libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_lzma.c") });
        libtiff.linkSystemLibrary("lzma");
    }

    if (enable_zip) {
        libtiff.addCSourceFile(.{ .file = b.path("libtiff/tif_zip.c") });

        if (b.lazyDependency("libz", .{
            .target = target,
            .optimize = optimize,
        })) |libz| {
            libtiff.linkLibrary(libz.artifact("z"));
        }
    }

    switch (target.result.os.tag) {
        .windows => libtiff.addCSourceFile(.{ .file = b.path("./libtiff/tif_win32.c") }),
        else => libtiff.addCSourceFile(.{ .file = b.path("./libtiff/tif_unix.c") }),
    }

    b.installArtifact(libtiff);

    // tools
    const tiffdump = b.addExecutable(.{
        .name = "tiffdump",
        .target = target,
        .optimize = optimize,
    });
    tiffdump.root_module.linkLibrary(libtiff);
    tiffdump.root_module.linkLibrary(tiff_port);
    tiffdump.root_module.addCSourceFile(.{ .file = b.path("./tools/tiffdump.c") });
    b.installArtifact(tiffdump);

    const tiffcmp = b.addExecutable(.{
        .name = "tiffcmp",
        .target = target,
        .optimize = optimize,
    });
    tiffcmp.root_module.linkLibrary(libtiff);
    tiffcmp.root_module.linkLibrary(tiff_port);
    tiffcmp.root_module.addCSourceFile(.{ .file = b.path("./tools/tiffcmp.c") });
    b.installArtifact(tiffcmp);

    const tiffinfo = b.addExecutable(.{
        .name = "tiffinfo",
        .target = target,
        .optimize = optimize,
    });
    tiffinfo.root_module.linkLibrary(libtiff);
    tiffinfo.root_module.linkLibrary(tiff_port);
    tiffinfo.root_module.addCSourceFile(.{ .file = b.path("./tools/tiffinfo.c") });
    b.installArtifact(tiffinfo);
}
