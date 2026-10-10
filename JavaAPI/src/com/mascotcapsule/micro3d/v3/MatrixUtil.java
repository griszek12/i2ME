/*
 * Pure Java replacement for android.opengl.Matrix.
 * Only the methods used by MascotCapsule Render.java are implemented.
 */

package com.mascotcapsule.micro3d.v3;

class MatrixUtil {

    /**
     * Multiplies two 4x4 column-major matrices: result = lhs * rhs
     * Compatible with android.opengl.Matrix.multiplyMM
     */
    static void multiplyMM(float[] result, int resultOffset,
                            float[] lhs, int lhsOffset,
                            float[] rhs, int rhsOffset) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                float sum = 0;
                for (int k = 0; k < 4; k++) {
                    sum += lhs[lhsOffset + i + k * 4] * rhs[rhsOffset + k + j * 4];
                }
                result[resultOffset + i + j * 4] = sum;
            }
        }
    }

    /**
     * Multiplies a 4x4 matrix by a 4-component vector: resultVec = lhsMat * rhsVec
     * Compatible with android.opengl.Matrix.multiplyMV
     */
    static void multiplyMV(float[] resultVec, int resultVecOffset,
                            float[] lhsMat, int lhsMatOffset,
                            float[] rhsVec, int rhsVecOffset) {
        for (int i = 0; i < 4; i++) {
            float sum = 0;
            for (int k = 0; k < 4; k++) {
                sum += lhsMat[lhsMatOffset + i + k * 4] * rhsVec[rhsVecOffset + k];
            }
            resultVec[resultVecOffset + i] = sum;
        }
    }
}
