//Copyright © 2020-2021 Mehmet Kaan Uluç <kaanuluc@protonmail.com>
//
//This software is provided 'as-is', without any express or implied
//warranty. In no event will the authors be held liable for any damages
//arising from the use of this software.
//
//Permission is granted to anyone to use this software for any purpose,
//including commercial applications, and to alter it and redistribute it
//freely, subject to the following restrictions:
//
//1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would
//   be appreciated but is not required.
//
//2. Altered source versions must be plainly marked as such, and must not
//   be misrepresented as being the original software.
//
//3. This notice may not be removed or altered from any source
//   distribution.

const std = @import("std");

pub const Error = error{ FailedtoAllocate, IsNotUnique, InvalidID };

pub fn UniqueList(comptime generic_type: type) type {
    return struct {
        pub const T = generic_type;
        const Self = @This();

        pub const Item = struct {
            data: ?T = null,
            id: u64 = 0,
        };

        alloc: *std.mem.Allocator = undefined,
        items: []Item = undefined,

        /// Iterator
        pub const Iterator = struct {
            parent: *const Self = undefined,
            index: usize = undefined,

            pub fn next(it: *Iterator) ?*Item {
                if (it.index >= it.parent.items.len) return null;
                const result = &it.parent.items[it.index];
                it.index += 1;
                return result;
            }

            /// Reset the iterator
            pub fn reset(it: *Iterator) void {
                it.index = 0;
            }
        };

        /// Initializes the UniqueList
        pub fn init(alloc: *std.mem.Allocator, reserve: usize) Error!Self {
            var self = Self{
                .alloc = alloc,
            };

            self.items = self.alloc.alloc(Item, reserve + 1) catch return Error.FailedtoAllocate;
            self.clear();
            return self;
        }

        /// Deinitializes the UniqueList
        pub fn deinit(self: Self) void {
            self.alloc.free(self.items);
        }

        /// Clears the list
        pub fn clear(self: *Self) void {
            var i: usize = 0;
            while (i < self.items.len) : (i += 1) {
                self.items[i].data = null;
                self.items[i].id = 0;
            }
        }

        /// Reserves memory
        pub fn reserveSlots(self: *Self, reserve: usize) Error!void {
            const epos = self.end();
            self.items = self.alloc.realloc(self.items, self.items.len + reserve) catch return Error.FailedtoAllocate;

            var i: usize = epos;
            while (i < self.items.len) : (i += 1) {
                self.items[i].data = null;
            }
        }

        /// Returns the end of the list
        pub fn end(self: Self) usize {
            return self.items.len;
        }

        /// Is the given id unique?
        pub fn isUnique(self: Self, id: u64) bool {
            var i: usize = 0;
            while (i < self.items.len) : (i += 1) {
                if (self.items[i].data != null and self.items[i].id == id) return false;
            }
            return true;
        }

        /// Returns an unique id 
        pub fn findUnique(self: Self) u64 {
            var i: u64 = 0;
            while (i < self.items.len + 1) : (i += 1) {
                if (self.isUnique(i)) return i;
            }
            @panic("Probably integer overflow and how tf did you end up here anyways?");
        }

        /// Is the given item slot empty?
        pub fn isEmpty(self: Self, index: u64) bool {
            if (self.items[index].data != null) return false;
            return true;
        }

        /// Inserts an item with given id and index
        /// Can(& will) overwrite into existing index if id is unique
        pub fn insertAt(self: *Self, id: u64, index: usize, data: T) Error!void {
            if (!self.isUnique(id)) return Error.IsNotUnique;
            self.items[index].data = data;
            self.items[index].id = id;
        }

        /// Appends an item with given id
        /// into appropriate item slot
        pub fn append(self: *Self, id: u64, data: T) Error!void {
            var i: usize = 0;
            while (i < self.items.len) : (i += 1) {
                if (self.isEmpty(i)) {
                    return self.insertAt(id, i, data);
                }
            }
            try self.reserveSlots(2);
            return self.insertAt(id, self.end() - 1, data);
        }

        /// Removes the item with given id
        pub fn remove(self: *Self, id: u64) Error!void {
            var i: usize = 0;
            while (i < self.items.len) : (i += 1) {
                if (self.items[i].data != null and self.items[i].id == id) {
                    self.items[i].data = null;
                    return;
                }
            }

            return Error.InvalidID;
        }

        /// Returns the data with given id
        pub fn get(self: Self, id: u64) Error!T {
            var i: usize = 0;
            while (i < self.items.len) : (i += 1) {
                if (self.items[i].data != null and self.items[i].id == id) return self.items[i].data.?;
            }
            return Error.InvalidID;
        }

        /// Returns the ptr to the data with given id
        pub fn getPtr(self: Self, id: u64) Error!*T {
            var i: usize = 0;
            while (i < self.items.len) : (i += 1) {
                if (self.items[i].data != null and self.items[i].id == id) return &self.items[i].data.?;
            }
            return Error.InvalidID;
        }

        /// Returns the iterator
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .parent = self,
                .index = 0,
            };
        }
    };
}
