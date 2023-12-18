const bpf = @cImport({
    @cInclude("linux/types.h");
    @cInclude("linux/bpf.h");
    @cInclude("bpf/bpf_helpers.h");
});
const std = @import("std");

export const _license linksection("license") = "GPL".*;

export fn print_number(_: ?*anyopaque) linksection("perf_event") c_int {
    const printed = bpf.bpf_trace_printk.?("Hello from Zig! The answer to every question is: {}\n", 42);
    if (printed < 0) {
        return 1;
    }
    return 0;
}
