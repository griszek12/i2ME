package com.mascotcapsule.micro3d.v3;

import java.nio.Buffer;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import org.mini.reflect.ReflectArray;

/**
 * Extracts raw memory address from java.nio.Buffer for native GL calls.
 * Uses miniJVM's ReflectArray.getBodyPtr() on the backing array.
 *
 * IMPORTANT: anonymous view buffers (from ByteBuffer.asFloatBuffer()) do NOT
 * have a backing array. For those, we must use the parent ByteBuffer's array.
 * Best practice: use createFloatBuffer() instead of allocateDirect().asFloatBuffer().
 */
class BufferUtils {

    /**
     * Create a FloatBuffer with a valid native address (backed by float[]).
     * Use this instead of ByteBuffer.allocateDirect(...).asFloatBuffer()
     * which creates view buffers without accessible backing arrays.
     */
    static FloatBuffer createFloatBuffer(int numFloats) {
        return FloatBuffer.allocate(numFloats);
    }

    /**
     * Create a ByteBuffer with a valid native address.
     */
    static ByteBuffer createByteBuffer(int numBytes) {
        return ByteBuffer.allocateDirect(numBytes).order(ByteOrder.nativeOrder());
    }

    static long getAddress(Buffer buffer) {
        if (buffer == null) return 0;
        try {
            // FloatBufferImpl (from FloatBuffer.allocate) has hasArray()=true
            if (buffer instanceof FloatBuffer) {
                FloatBuffer fb = (FloatBuffer) buffer;
                if (fb.hasArray()) {
                    return ReflectArray.getBodyPtr(fb.array());
                }
            }
            // ByteBufferImpl (from ByteBuffer.allocateDirect) has hasArray()=true
            if (buffer instanceof ByteBuffer) {
                ByteBuffer bb = (ByteBuffer) buffer;
                if (bb.hasArray()) {
                    return ReflectArray.getBodyPtr(bb.array());
                }
            }
        } catch (Exception e) {
            System.err.println("[micro3d] BufferUtils.getAddress error: " + e);
        }
        System.err.println("[micro3d] WARNING: Cannot get address for " + buffer.getClass().getName());
        return 0;
    }
}
