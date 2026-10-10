/*
 * OpenGL ES 2.0 bridge for MascotCapsule micro3D on iOS.
 * Static native methods proxy 1:1 to real GLES20 calls via miniJVM native registration.
 * Constants match android.opengl.GLES20 values (which match GL ES 2.0 spec).
 */

package com.mascotcapsule.micro3d.v3;

import java.nio.Buffer;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;

class GLES20 {
    // Error
    static final int GL_NO_ERROR = 0;

    // Boolean
    static final int GL_FALSE = 0;
    static final int GL_TRUE = 1;

    // Clear buffer bits
    static final int GL_DEPTH_BUFFER_BIT = 0x00000100;
    static final int GL_STENCIL_BUFFER_BIT = 0x00000400;
    static final int GL_COLOR_BUFFER_BIT = 0x00004000;

    // Primitives
    static final int GL_POINTS = 0x0000;
    static final int GL_LINES = 0x0001;
    static final int GL_LINE_LOOP = 0x0002;
    static final int GL_LINE_STRIP = 0x0003;
    static final int GL_TRIANGLES = 0x0004;
    static final int GL_TRIANGLE_STRIP = 0x0005;
    static final int GL_TRIANGLE_FAN = 0x0006;

    // Enable/Disable
    static final int GL_CULL_FACE = 0x0B44;
    static final int GL_DEPTH_TEST = 0x0B71;
    static final int GL_STENCIL_TEST = 0x0B90;
    static final int GL_BLEND = 0x0BE2;
    static final int GL_SCISSOR_TEST = 0x0C11;

    // Depth
    static final int GL_LESS = 0x0201;
    static final int GL_LEQUAL = 0x0203;

    // Winding
    static final int GL_CW = 0x0900;
    static final int GL_CCW = 0x0901;

    // Blend
    static final int GL_ZERO = 0;
    static final int GL_ONE = 1;
    static final int GL_SRC_COLOR = 0x0300;
    static final int GL_ONE_MINUS_SRC_COLOR = 0x0301;
    static final int GL_SRC_ALPHA = 0x0302;
    static final int GL_ONE_MINUS_SRC_ALPHA = 0x0303;
    static final int GL_DST_ALPHA = 0x0304;
    static final int GL_ONE_MINUS_DST_ALPHA = 0x0305;
    static final int GL_CONSTANT_COLOR = 0x8001;
    static final int GL_FUNC_ADD = 0x8006;
    static final int GL_FUNC_REVERSE_SUBTRACT = 0x800B;

    // Data types
    static final int GL_UNSIGNED_BYTE = 0x1401;
    static final int GL_FLOAT = 0x1406;

    // Texture
    static final int GL_TEXTURE_2D = 0x0DE1;
    static final int GL_TEXTURE0 = 0x84C0;
    static final int GL_TEXTURE1 = 0x84C1;
    static final int GL_TEXTURE2 = 0x84C2;
    static final int GL_TEXTURE_MAG_FILTER = 0x2800;
    static final int GL_TEXTURE_MIN_FILTER = 0x2801;
    static final int GL_TEXTURE_WRAP_S = 0x2802;
    static final int GL_TEXTURE_WRAP_T = 0x2803;
    static final int GL_NEAREST = 0x2600;
    static final int GL_LINEAR = 0x2601;
    static final int GL_CLAMP_TO_EDGE = 0x812F;

    // Pixel format
    static final int GL_RGBA = 0x1908;

    // Buffer
    static final int GL_ARRAY_BUFFER = 0x8892;
    static final int GL_STREAM_DRAW = 0x88E0;

    // Shader
    static final int GL_VERTEX_SHADER = 0x8B31;
    static final int GL_FRAGMENT_SHADER = 0x8B30;
    static final int GL_COMPILE_STATUS = 0x8B81;
    static final int GL_LINK_STATUS = 0x8B82;

    // --- State ---
    static native void glEnable(int cap);
    static native void glDisable(int cap);
    static native void glViewport(int x, int y, int width, int height);
    static native void glScissor(int x, int y, int width, int height);
    static native void glClearColor(float r, float g, float b, float a);
    static native void glClear(int mask);
    static native void glDepthMask(boolean flag);
    static native void glDepthFunc(int func);
    static native int glGetError();
    static native void glFlush();

    // --- Blend ---
    static native void glBlendFunc(int sfactor, int dfactor);
    static native void glBlendFuncSeparate(int srcRGB, int dstRGB, int srcAlpha, int dstAlpha);
    static native void glBlendEquation(int mode);
    static native void glBlendColor(float r, float g, float b, float a);

    // --- Cull ---
    static native void glCullFace(int mode);
    static native void glFrontFace(int mode);

    // --- Shader ---
    static native int glCreateShader(int type);
    static native void glShaderSource(int shader, String source);
    static native void glCompileShader(int shader);
    static native void glGetShaderiv(int shader, int pname, int[] params, int offset);
    static native String glGetShaderInfoLog(int shader);
    static native void glDeleteShader(int shader);

    // --- Program ---
    static native int glCreateProgram();
    static native void glAttachShader(int program, int shader);
    static native void glDetachShader(int program, int shader);
    static native void glLinkProgram(int program);
    static native void glGetProgramiv(int program, int pname, int[] params, int offset);
    static native String glGetProgramInfoLog(int program);
    static native void glUseProgram(int program);
    static native void glDeleteProgram(int program);
    static native void glReleaseShaderCompiler();

    // --- Attribute ---
    static native int glGetAttribLocation(int program, String name);
    static native void glEnableVertexAttribArray(int index);
    static native void glDisableVertexAttribArray(int index);
    // With buffer offset (for VBO)
    static native void glVertexAttribPointer(int index, int size, int type, boolean normalized, int stride, int offset);
    // With direct buffer address (for client-side arrays)
    // We pass the Buffer's internal address (long pointer) to avoid Buffer object access issues in miniJVM native
    static native void glVertexAttribPointerAddr(int index, int size, int type, boolean normalized, int stride, long address);

    // Convenience: dispatch based on argument type — extracts address from Buffer
    // Accounts for buffer.position() as byte offset
    static void glVertexAttribPointer(int index, int size, int type, boolean normalized, int stride, Buffer buffer) {
        long addr = BufferUtils.getAddress(buffer);
        if (addr != 0) {
            int pos = buffer.position();
            if (pos > 0) {
                // position is in elements — compute byte offset
                int elemSize = (buffer instanceof FloatBuffer) ? 4 : 1;
                addr += (long) pos * elemSize;
            }
        }
        glVertexAttribPointerAddr(index, size, type, normalized, stride, addr);
    }

    // --- Uniform ---
    static native int glGetUniformLocation(int program, String name);
    static native void glUniform1i(int location, int v0);
    static native void glUniform1f(int location, float v0);
    static native void glUniform2f(int location, float v0, float v1);
    static native void glUniform3f(int location, float v0, float v1, float v2);
    static native void glUniform3fvAddr(int location, int count, long address);
    static void glUniform3fv(int location, int count, FloatBuffer value) {
        glUniform3fvAddr(location, count, BufferUtils.getAddress(value));
    }
    static native void glUniformMatrix4fv(int location, int count, boolean transpose, float[] value, int offset);

    // --- Texture ---
    static native void glGenTextures(int n, int[] textures, int offset);
    static native void glDeleteTextures(int n, int[] textures, int offset);
    static native void glBindTexture(int target, int texture);
    static native void glActiveTexture(int texture);
    static native void glTexParameteri(int target, int pname, int param);
    static native boolean glIsTexture(int texture);
    static native void glTexImage2DAddr(int target, int level, int internalformat,
                                        int width, int height, int border,
                                        int format, int type, long address);
    static void glTexImage2D(int target, int level, int internalformat,
                              int width, int height, int border,
                              int format, int type, Buffer pixels) {
        glTexImage2DAddr(target, level, internalformat, width, height, border,
                         format, type, BufferUtils.getAddress(pixels));
    }

    // --- Buffer objects ---
    static native void glGenBuffers(int n, int[] buffers, int offset);
    static native void glDeleteBuffers(int n, int[] buffers, int offset);
    static native void glBindBuffer(int target, int buffer);
    static native void glBufferDataAddr(int target, int size, long address, int usage);
    static void glBufferData(int target, int size, Buffer data, int usage) {
        glBufferDataAddr(target, size, BufferUtils.getAddress(data), usage);
    }

    // --- Draw ---
    static native void glDrawArrays(int mode, int first, int count);

    // --- Read ---
    static native void glReadPixelsAddr(int x, int y, int width, int height,
                                        int format, int type, long address);
    static void glReadPixels(int x, int y, int width, int height,
                              int format, int type, Buffer pixels) {
        glReadPixelsAddr(x, y, width, height, format, type, BufferUtils.getAddress(pixels));
    }

    // === Context management (iOS-specific, not in standard GLES20) ===
    static native void mc3dInit(int width, int height);
    static native void mc3dBind();
    static native void mc3dRelease();
    static native void mc3dDestroy();
    static native void mc3dResize(int width, int height);
}
