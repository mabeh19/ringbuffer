package ringbuffer

import "core:fmt"
import "core:slice"
import "core:testing"
import "core:log"
import "base:builtin"


RingBuffer :: struct($T: typeid) {
    data: [dynamic]T,
    idx: int,
    dyn: bool,
    looped: bool,
}

length :: proc(buffer: RingBuffer($T)) -> int
{
    return buffer.looped ? len(buffer.data) : buffer.idx
}

push_elem :: proc(buffer: ^RingBuffer($T), elem: T) 
{
    if buffer.dyn {
        if buffer.idx == len(buffer.data) {
            resize(&buffer.data, 2 * len(buffer.data))
        }
    }
    buffer.data[buffer.idx] = elem
    buffer.idx += 1

    if !buffer.dyn && buffer.idx == len(buffer.data) {
        buffer.looped = true
        buffer.idx %= len(buffer.data)
    }
}

push_slice :: proc(buffer: ^RingBuffer($T), slice: []T) 
{
    if buffer.dyn {
        for buffer.idx + len(slice) > len(buffer.data) {
            resize(&buffer.data, 2 * len(buffer.data))
        }
    }
    first_slice := min(len(buffer.data) - buffer.idx, len(slice))
    second_slice := len(slice) - first_slice

    copy(buffer.data[buffer.idx:][:first_slice], slice[:first_slice])

    if second_slice > 0 {
        copy(buffer.data[:second_slice], slice[first_slice:])
    }

    new_idx := (buffer.idx + len(slice)) % len(buffer.data)
    if new_idx < buffer.idx {
        buffer.looped = true
    }
    buffer.idx = new_idx
}

push :: proc{push_elem, push_slice}

get :: proc(buffer: RingBuffer($T), idx: int) -> T 
{
    return buffer.data[(buffer.idx + idx) % len(buffer.data)]
}

realign :: proc(buffer: ^RingBuffer($T)) 
{
    slice.rotate_left(buffer.data[:], buffer.idx)
    buffer.idx = 0
}

parts :: proc(buffer: RingBuffer($T)) -> (first: []T, second: []T)
{
    first = buffer.data[:buffer.idx]

    if buffer.looped {
        second = first
        first = buffer.data[buffer.idx:]
    }

    return
}

new :: proc(n: int, $T: typeid, dyn: bool) -> RingBuffer(T)
{
    return RingBuffer(T){
        data = make([dynamic]T, n),
        idx = 0,
        dyn = dyn,
        looped = false,
    }
}

clear :: proc(buffer: ^RingBuffer($T))
{
    slice.fill(buffer.data[:], 0)
    buffer.idx = 0
    buffer.looped = false
}

@test
test_push_elem :: proc(t: ^testing.T)
{
    buf := new(4, int, false)
    
    push_elem(&buf, 2)
    push_elem(&buf, 3)
    push_elem(&buf, 4)
    push_elem(&buf, 5)
    testing.expect(t, buf.data[0] == 2)
    testing.expect(t, buf.data[1] == 3)
    testing.expect(t, buf.data[2] == 4)
    testing.expect(t, buf.data[3] == 5)

    push_elem(&buf, 1)
    testing.expect(t, buf.data[0] == 1)
}

@test
test_push_slice :: proc(t: ^testing.T)
{
    buf := new(4, int, false)
    slice := []int{1,2,3,4}

    push_slice(&buf, slice)

    // buf = {1, 2, 3, 4}
    //        ^idx
    for _, i in slice {
        testing.expect_value(t, buf.data[i], slice[i])
    }

    push_slice(&buf, slice[1:])

    // buf = {2, 3, 4, 4}
    //                 ^idx
    for _, i in slice[1:] {
        testing.expect_value(t, buf.data[i], slice[1 + i])
    }

    push_slice(&buf, slice[:3])

    // buf = {2, 3, 4, 1}
    //              ^idx
    for _, i in slice[:3] {
        testing.expect_value(t, buf.data[(buf.idx + i + 1) % 4], slice[i])
    }
}

@test
test_get :: proc(t: ^testing.T)
{
    buf := new(4, int, false)
    slice := []int{1,2,3,4}

    push(&buf, slice)

    for i in 0..<len(slice) {
        testing.expect_value(t, get(buf, i), slice[i])
    }

    push(&buf, slice[2:])

    for i in 0..<len(slice[2:]) {
        testing.expect_value(t, get(buf, i), slice[2 + i])
        testing.expect_value(t, get(buf, i + 2), slice[2 + i])
    }
}

@test
test_align :: proc(t: ^testing.T)
{
    buf := new(4, int, false)
    slice := []int{1,2,3,4}

    push(&buf, slice)
    push(&buf, 5)

    realign(&buf)

    expected := []int{2,3,4,5}

    for x, i in expected {
        testing.expect(t, buf.data[i] == x)
    }

    push(&buf, 6)
    realign(&buf)

    expected = []int{3,4,5,6}

    for x, i in expected {
        testing.expect(t, buf.data[i] == x)
    }
}


@test
test_parts :: proc(t: ^testing.T)
{
    buf := new(4, int, false)
    s := []int{1, 2, 3}

    push(&buf, s)

    first, second := parts(buf)
    testing.expect_value(t, len(first), len(s))
    testing.expect(t, slice.equal(first[:3], s[:]))

    push(&buf, s)

    first, second = parts(buf)
    testing.expect(t, slice.equal(first , buf.data[2:]))
    testing.expect(t, slice.equal(second, buf.data[:2]))
}
