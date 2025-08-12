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

        values: []T,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{ .values = try allocator.alloc(T, n_elements) };
        }

        pub fn free(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.values);
        }

        pub fn zeros(allocator: std.mem.Allocator) !Self {
            const list = try allocator.alloc(T, n_elements);
            for (list) |*element| {
                element.* = 0.0;
            }

            return Self{ .values = list };
        }

        pub fn identity(allocator: std.mem.Allocator) !Self {
            var matrix = try zeros(allocator);
            errdefer matrix.free(allocator);

            if (rows != cols) {
                return MatrixError.OnlyForSquareMatrix;
            }

            for (0..rows) |row| {
                matrix.values[row * cols + row] = 1.0;
            }

            return matrix;
        }

        pub fn random(allocator: std.mem.Allocator) !Self {
            const list = try allocator.alloc(T, n_elements);
            var rnd = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            });
            const rand = rnd.random();

            for (list) |*element| {
                element.* = rand.float(f64);
            }

            return Self{ .values = list };
        }

        pub fn create(allocator: std.mem.Allocator, values: []const T) !Self {
            const list = try allocator.alloc(T, n_elements);

            for (values, list) |value, *element| {
                element.* = value;
            }

            return Self{ .values = list };
        }

        pub fn at(self: *Self, row: usize, col: usize) *T {
            return &self.values[row * cols + col];
        }

        pub fn add(allocator: std.mem.Allocator, input_1: Self, input_2: Self) !Self {
            const list = try allocator.alloc(T, n_elements);

            for (list, input_1.values, input_2.values) |*element, a, b| {
                element.* = a + b;
            }

            return Self{ .values = list };
        }

        pub fn sub(allocator: std.mem.Allocator, input_1: Self, input_2: Self) !Self {
            const list = try allocator.alloc(T, n_elements);

            for (list, input_1.values, input_2.values) |*element, a, b| {
                element.* = a - b;
            }

            return Self{ .values = list };
        }
    };
}

const Matrix2x2 = CreateMatrix(f64, 2, 2);

test "create a identity matrix" {
    var id_2 = try Matrix2x2.identity(testing.allocator);
    defer id_2.free(testing.allocator);

    try testing.expectApproxEqRel(1.0, id_2.values[0], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values[1], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values[2], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values[3], 1e-6);
}

test "non square matrix can not be identity" {
    try testing.expectError(MatrixError.OnlyForSquareMatrix, CreateMatrix(f64, 2, 1).identity(testing.allocator));
}

test "creating a matrix with random values" {
    var id_2 = try Matrix2x2.random(testing.allocator);
    defer id_2.free(testing.allocator);

    try testing.expect(0 <= id_2.values[0]);
    try testing.expect(1 >= id_2.values[0]);
    try testing.expect(0 <= id_2.values[1]);
    try testing.expect(1 >= id_2.values[1]);
    try testing.expect(0 <= id_2.values[2]);
    try testing.expect(1 >= id_2.values[2]);
    try testing.expect(0 <= id_2.values[3]);
    try testing.expect(1 >= id_2.values[3]);
}

test "creating a matrix with input values" {
    var id_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer id_2.free(testing.allocator);

    try testing.expectApproxEqRel(0.0, id_2.values[0], 1e-6);
    try testing.expectApproxEqRel(2.0, id_2.values[1], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values[2], 1e-6);
    try testing.expectApproxEqRel(6.0, id_2.values[3], 1e-6);
}

test "the at method gets the right values" {
    var id_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer id_2.free(testing.allocator);

    try testing.expectApproxEqRel(0.0, id_2.at(0, 0).*, 1e-6);
    try testing.expectApproxEqRel(2.0, id_2.at(0, 1).*, 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.at(1, 0).*, 1e+6);
    try testing.expectApproxEqRel(6.0, id_2.at(1, 1).*, 1e-6);
}

test "addition of matrices" {
    var input_1 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer input_1.free(testing.allocator);
    var input_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, -2.0, 3.0, 6.5 });
    defer input_2.free(testing.allocator);

    const actual = try Matrix2x2.add(testing.allocator, input_1, input_2);
    defer actual.free(testing.allocator);

    const expected = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, 0.0, 4.0, 12.5 });
    defer expected.free(testing.allocator);

    try testing.expectApproxEqRel(expected.values[0], actual.values[0], 1e-6);
    try testing.expectApproxEqRel(expected.values[1], actual.values[1], 1e-6);
    try testing.expectApproxEqRel(expected.values[2], actual.values[2], 1e-6);
    try testing.expectApproxEqRel(expected.values[3], actual.values[3], 1e-6);
}

test "substraction of matrices" {
    var input_1 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer input_1.free(testing.allocator);
    var input_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, -2.0, 3.0, 6.5 });
    defer input_2.free(testing.allocator);

    const actual = try Matrix2x2.sub(testing.allocator, input_1, input_2);
    defer actual.free(testing.allocator);

    const expected = try Matrix2x2.create(testing.allocator, &[_]f64{ -1.0, 4.0, -2.0, -0.5 });
    defer expected.free(testing.allocator);

    try testing.expectApproxEqRel(expected.values[0], actual.values[0], 1e-6);
    try testing.expectApproxEqRel(expected.values[1], actual.values[1], 1e-6);
    try testing.expectApproxEqRel(expected.values[2], actual.values[2], 1e-6);
    try testing.expectApproxEqRel(expected.values[3], actual.values[3], 1e-6);
}
