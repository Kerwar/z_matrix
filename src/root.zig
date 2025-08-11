const std = @import("std");
const testing = std.testing;

const MatrixError = error{
    OnlyForSquareMatrix,
};

pub fn CreateMatrix(T: type, comptime n_rows: usize, comptime n_cols: usize) type {
    return struct {
        const Self = @This();

        const rows = n_rows;
        const cols = n_cols;
        const n_elements = n_rows * n_cols;

        values: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) !Self {
            const list = try std.ArrayList(f64).initCapacity(allocator, rows * cols);
            return Self{ .values = list };
        }

        pub fn deinit(self: Self) void {
            self.values.deinit();
        }

        pub fn zeros(allocator: std.mem.Allocator) !Self {
            var list = try std.ArrayList(f64).initCapacity(allocator, rows * cols);
            list.appendNTimesAssumeCapacity(0.0, n_elements);

            return Self{ .values = list };
        }

        pub fn identity(allocator: std.mem.Allocator) !Self {
            var matrix = try zeros(allocator);
            errdefer matrix.deinit();

            if (rows != cols) {
                return MatrixError.OnlyForSquareMatrix;
            }

            for (0..rows) |row| {
                matrix.values.items[row * cols + row] = 1.0;
            }

            return matrix;
        }

        pub fn random(allocator: std.mem.Allocator) !Self {
            var list = try std.ArrayList(f64).initCapacity(allocator, rows * cols);
            var rnd = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            });
            const rand = rnd.random();

            for (0..n_elements) |_| {
                list.appendAssumeCapacity(rand.float(f64));
            }

            return Self{ .values = list };
        }

        pub fn create(allocator: std.mem.Allocator, values: []const T) !Self {
            var list = try std.ArrayList(f64).initCapacity(allocator, rows * cols);

            for (values) |value| {
                list.appendAssumeCapacity(value);
            }

            return Self{ .values = list };
        }
    };
}

const Matrix2x2 = CreateMatrix(f64, 2, 2);

test "create a identity matrix" {
    var id_2 = try Matrix2x2.identity(testing.allocator);
    defer id_2.deinit();

    try testing.expectApproxEqRel(1.0, id_2.values.items[0], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values.items[1], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values.items[2], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values.items[3], 1e-6);
}

test "non square matrix can not be identity" {
    try testing.expectError(MatrixError.OnlyForSquareMatrix, CreateMatrix(f64, 2, 1).identity(testing.allocator));
}

test "creating a matrix with random values" {
    var id_2 = try Matrix2x2.random(testing.allocator);
    defer id_2.deinit();

    try testing.expect(0 <= id_2.values.items[0]);
    try testing.expect(1 >= id_2.values.items[0]);
    try testing.expect(0 <= id_2.values.items[1]);
    try testing.expect(1 >= id_2.values.items[1]);
    try testing.expect(0 <= id_2.values.items[2]);
    try testing.expect(1 >= id_2.values.items[2]);
    try testing.expect(0 <= id_2.values.items[3]);
    try testing.expect(1 >= id_2.values.items[3]);
}

test "creating a matrix with input values" {
    var id_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer id_2.deinit();

    try testing.expectApproxEqRel(0.0, id_2.values.items[0], 1e-6);
    try testing.expectApproxEqRel(2.0, id_2.values.items[1], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values.items[2], 1e-6);
    try testing.expectApproxEqRel(6.0, id_2.values.items[3], 1e-6);
}
