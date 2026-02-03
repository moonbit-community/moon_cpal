# CoreAudio callback buffers and "zero-copy" (AudioQueue)

Today the macOS backend uses **AudioQueue** callbacks and bridges them into MoonBit closures.
For both input and output we currently **copy** audio bytes between the AudioQueue buffer
(`AudioQueueBufferRef->mAudioData`) and a MoonBit `FixedArray[Byte]` passed to the user callback.

This note documents why we do not provide a true "zero-copy" `Data` view over the AudioQueue
buffer today.

## Why we cannot safely wrap `mAudioData` as `FixedArray[Byte]`

In the MoonBit C backend, `Bytes` / `FixedArray[Byte]` are managed objects with:

- an object header stored **immediately before** the byte payload
- reference counting and runtime-managed allocation/free behavior

See `~/.moon/include/moonbit.h`:

- `typedef uint8_t *moonbit_bytes_t;`
- `#define Moonbit_object_header(obj) ((struct moonbit_object*)(obj) - 1)`

Because the object header must live at `bytes_ptr - sizeof(moonbit_object)`, MoonBit cannot
directly treat an arbitrary external pointer (like `AudioQueueBufferRef->mAudioData`) as a
`Bytes`/`FixedArray[Byte]` without either:

1) allocating a MoonBit array and copying data into it, or
2) fabricating a MoonBit object header in memory we do not own and convincing the runtime to
   never free it (which becomes unsound as soon as user code stores the buffer beyond callback).

Additionally, even "clever" tricks such as shifting `mAudioData` forward to leave space for a
fake MoonBit header in the AudioQueue buffer still require preventing the MoonBit runtime from
ever decrementing/freeing that object, and cannot enforce the "buffer valid only during callback"
rule at the type level (unlike Rust lifetimes in upstream `cpal`).

## Current design (copy + reuse buffers)

We keep the semantics simple and predictable:

- allocate MoonBit byte buffers once (output uses a small ring; input uses a scratch buffer)
- copy bytes between MoonBit buffers and AudioQueue buffers per callback
- pass a `Data` containing a mutable `FixedArray[Byte]` to user callbacks

This avoids relying on undocumented ABIs and prevents "freeing foreign memory" hazards.

## Future work

A true zero-copy design likely requires runtime/toolchain support, e.g.:

- an official "bytes view" type backed by an external pointer + length with a well-defined
  borrow-only lifetime model, or
- a safe/unsafe split API where the callback receives an opaque external buffer handle and only
  exposes explicit read/write primitives (still tricky to make fast).

