package ringbuffer

import "core:fmt"
import "core:slice"
import "core:testing"

RingBuffer :: struct($N: int, $T: typeid) where N > 0 {
    data: [N]T,
    idx: int,
}


push_elem :: proc(buffer: ^RingBuffer($N, $T), elem: T) 
{
    buffer.data[buffer.idx] = elem
    buffer.idx = (buffer.idx + 1) % N
}

push_slice :: proc(buffer: ^RingBuffer($N, $T), slice: []T) 
{
    first_slice := min(N - buffer.idx, len(slice))
    second_slice := len(slice) - first_slice

    copy(buffer.data[buffer.idx:][:first_slice], slice[:first_slice])

    if second_slice > 0 {
        copy(buffer.data[:second_slice], slice[first_slice:])
    }
}

push :: proc{push_elem, push_slice}

get :: proc(buffer: ^RingBuffer($N, $T), idx: int) -> T 
{
    return buffer.data[(buffer.idx + idx) % N]
}

realign :: proc(buffer: ^RingBuffer($N, $T)) 
{
    slice.rotate_left(buffer.data[:], buffer.idx)
    buffer.idx = 0
}


@test
test_push_elem :: proc(t: ^testing.T)
{
    buf := RingBuffer(4, int) {}
    
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
    buf := RingBuffer(4, int) {}
    slice := []int{1,2,3,4}

    push_slice(&buf, slice)

    for _, i in slice {
        testing.expect(t, buf.data[i] == slice[i])
    }

    push_slice(&buf, slice[1:])

    for _, i in slice[1:] {
        testing.expect(t, buf.data[i] == slice[1 + i])
    }

    push_slice(&buf, slice[:3])

    for _, i in slice[:3] {
        testing.expect(t, buf.data[(buf.idx + i) % 4] == slice[i])
    }
}

@test
test_get :: proc(t: ^testing.T)
{
    buf := RingBuffer(4, int) {}
    slice := []int{1,2,3,4}

    push(&buf, slice)

    for i in 0..<len(slice) {
        testing.expect(t, get(&buf, i) == slice[i])
    }

    push(&buf, slice[2:])

    for i in 0..<len(slice[2:]) {
        testing.expect(t, get(&buf, i) == slice[2 + i])
        testing.expect(t, get(&buf, i + 2) == slice[2 + i])
    }
}

@test
test_align :: proc(t: ^testing.T)
{
    buf := RingBuffer(4, int) {}
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
