const std = @import("std");
// defined in build.zig as a module
const zbpf = @import("zbpf");
const linux = std.os.linux;
const BPF = linux.BPF;

// include libbpf.h
const libbpf = @cImport({
    @cInclude("bpf/libbpf.h");
});

// Embed the object file built from probes.zig
const ebpf_obj = @embedFile("./artifacts/probes.o");

comptime {
    @setEvalBranchQuota(5000);
}

pub fn main() !noreturn {
    // Create perf_event attributes to profile at a frequency of 1Hz
    var perf_attr = linux.perf_event_attr{
        .type = linux.PERF.TYPE.HARDWARE,
        .config = @intFromEnum(linux.PERF.COUNT.HW.CPU_CYCLES),
        .size = @sizeOf(linux.perf_event_attr),
        .sample_period_or_freq = 1,
    };

    // Load the eBPF program into the kernel
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const bytes = try gpa.allocator().dupe(u8, ebpf_obj);
    defer gpa.allocator().free(bytes);

    const obj = libbpf.bpf_object__open_mem(bytes.ptr, bytes.len, null);
    if (obj == null) {
        std.debug.print("failed to open bpf object: {}\n", .{std.os.errno(-1)});
        return ExecutionError.LibbpfObjectOpen;
    }
    defer libbpf.bpf_object__close(obj);

    const ret = libbpf.bpf_object__load(obj);
    if (ret != 0) {
        std.debug.print("failed to load bpf object: {}\n", .{std.os.errno(-1)});
        return ExecutionError.LibbpfObjectLoad;
    }

    var links = std.ArrayList(*libbpf.bpf_link).init(gpa.allocator());
    defer {
        for (links.items) |link| {
            _ = libbpf.bpf_link__destroy(link);
        }
        links.deinit();
    }

    var cur_prog: ?*libbpf.bpf_program = null;
    while (libbpf.bpf_object__next_program(obj, cur_prog)) |prog| : (cur_prog = prog) {
        try links.append(libbpf.bpf_program__attach(prog) orelse {
            std.debug.print("failed to attach prog {s}: {}\n", .{ libbpf.bpf_program__name(prog), std.os.errno(-1) });
            return ExecutionError.LibbpfProgramAttach;
        });
    }

    // TODO: start with only CPU 0, but we should have a for loop here.
    // pid=-1 means all PIDs.
    const popen_fd = linux.perf_event_open(&perf_attr, -1, 0, -1, linux.PERF.FLAG.FD_CLOEXEC);
    if (popen_fd < 0) {
        std.debug.print("perf_event_open failed: error code {d}\n", .{popen_fd});
        return ExecutionError.PerEventOpenFailed;
    } else {
        std.debug.print("perf_event_open fd: {d}\n", .{popen_fd});
    }
    // Attach the program to the perf event

    // Keep reading the perf event ring buffer until we get an error
    while (true) {}
}

const ExecutionError = error{
    PerEventOpenFailed,
    LibbpfObjectOpen,
    LibbpfObjectLoad,
    LibbpfProgramAttach,
};
