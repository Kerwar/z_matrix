const std = @import("std");
const testing = std.testing;

pub fn CreateMatrix(T: type, n_rows: usize, n_cols: usize) type {
    return struct {
        const Self = @This();

        const rows = n_rows;
        const cols = n_cols;

        values: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) !Self {
            const list = try std.ArrayList(f64).initCapacity(allocator, rows * cols);
            return Self{ .values = list };
        }

        pub fn deinit(self: Self) void {
            self.values.deinit();
        }

        pub fn identity(self: *Self) void {
            std.debug.assert(rows == cols);
            std.debug.assert(self.values.capacity == rows * cols);

            if (self.values.items.len != 0) {
                self.values.clearAndFree();
                self.values.ensureTotalCapacity(rows * cols) catch {
                    !unreachable;
                };
            }
            self.values.appendNTimesAssumeCapacity(0.0, rows * cols);

            for (0..rows) |row| {
                self.values.items[row * cols + row] = 1.0;
            }
        }
    };
}

const Matrix2x2 = CreateMatrix(f64, 2, 2);

test "create a identity matrix" {
    var id_2 = try Matrix2x2.init(testing.allocator);
    defer id_2.deinit();
    id_2.identity();

    try testing.expectApproxEqRel(1.0, id_2.values.items[0], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values.items[1], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values.items[2], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values.items[3], 1e-6);
}
