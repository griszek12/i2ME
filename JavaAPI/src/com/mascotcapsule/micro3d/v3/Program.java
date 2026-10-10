/*
 *  Copyright 2020 Yury Kharchenko
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

package com.mascotcapsule.micro3d.v3;

import static com.mascotcapsule.micro3d.v3.GLES20.*;
import static com.mascotcapsule.micro3d.v3.Utils.TO_FLOAT;

abstract class Program {
	static Tex tex;
	static Color color;
	static Simple simple;
	static Sprite sprite;
	private static boolean isCreated;

	final int id;
	int uAmbIntensity;
	int uDirIntensity;
	int uLightDir;
	int uMatrix;
	int uMatrixMV;
	int aPosition;
	int aNormal;
	int aColorData;
	int aMaterial;
	private int vertexId;
	private int fragmentId;

	Program(String vertexShader, String fragmentShader) {
		id = createProgram(vertexShader, fragmentShader);
		getLocations();
		Render.checkGlError("getLocations");
	}

	static void create() {
		if (isCreated) return;
		tex = new Tex();
		color = new Color();
		simple = new Simple();
		sprite = new Sprite();
		glReleaseShaderCompiler();
	}

	private int createProgram(String vertexShaderCode, String fragmentShaderCode) {
		vertexId = loadShader(GL_VERTEX_SHADER, vertexShaderCode);
		fragmentId = loadShader(GL_FRAGMENT_SHADER, fragmentShaderCode);

		int program = glCreateProgram();             // create empty OpenGL Program
		glAttachShader(program, vertexId);   // add the vertex shader to program
		glAttachShader(program, fragmentId); // add the fragment shader to program

		glLinkProgram(program);                  // create OpenGL program executables
		int[] status = new int[1];
		glGetProgramiv(program, GL_LINK_STATUS, status, 0);
		if (status[0] == 0) {
			String s = glGetProgramInfoLog(program);
			System.err.println("[micro3d] createProgram: " + s);
		}
		Render.checkGlError("glLinkProgram");
		return program;
	}

	/**
	 * Utility method for compiling a OpenGL shader.
	 *
	 * <p><strong>Note:</strong> When developing shaders, use the checkGlError()
	 * method to debug shader coding errors.</p>
	 *
	 * @param type       - Vertex or fragment shader type.
	 * @param shaderCode - String containing the shader code.
	 * @return - Returns an id for the shader.
	 */
	protected int loadShader(int type, String shaderCode) {

		// create a vertex shader type (GLES20.GL_VERTEX_SHADER)
		// or a fragment shader type (GLES20.GL_FRAGMENT_SHADER)
		int shader = glCreateShader(type);

		// add the source code to the shader and compile it
		glShaderSource(shader, shaderCode);
		glCompileShader(shader);
		int[] status = new int[1];
		glGetShaderiv(shader, GL_COMPILE_STATUS, status, 0);
		if (status[0] == 0) {
			String s = glGetShaderInfoLog(shader);
			System.err.println("[micro3d] loadShader: " + s);
		}
		Render.checkGlError("glCompileShader");
		return shader;
	}

	void use() {
		glUseProgram(id);
	}

	protected abstract void getLocations();

	static void release() {
		if (!isCreated) return;
		tex.delete();
		color.delete();
		simple.delete();
		sprite.delete();
		isCreated = false;
	}

	void delete() {
		glDetachShader(id, vertexId);
		glDetachShader(id, fragmentId);
		glDeleteShader(vertexId);
		glDeleteShader(fragmentId);
		glDeleteProgram(id);
		Render.checkGlError("program delete");
	}

	public void setLight(Light light) {
		if (light == null) {
			glUniform1f(uAmbIntensity, -1.0f);
			return;
		}
		glUniform1f(uAmbIntensity, Math.max(0, Math.min(light.getAmbientIntensity(), 4096)) * TO_FLOAT);
		glUniform1f(uDirIntensity, Math.max(0, Math.min(light.getParallelLightIntensity(), 16384)) * TO_FLOAT);
		Vector3D d = light.getDirection();
		float x = d.x;
		float y = d.y;
		float z = d.z;
		float rlf = -1.0f / (float) Math.sqrt(x * x + y * y + z * z);
		glUniform3f(uLightDir, x * rlf, y * rlf, z * rlf);
	}

	static final class Color extends Program {
		private static final String VERTEX =
				"uniform mat4 uMatrix;\n" +
				"uniform mat4 uMatrixMV;\n" +
				"uniform vec3 uColor;\n" +
				"uniform float uAmbIntensity;\n" +
				"uniform bool uIsPrimitive;\n" +
				"attribute vec4 aPosition;\n" +
				"attribute vec3 aNormal;\n" +
				"attribute vec3 aColorData;\n" +
				"attribute vec2 aMaterial;\n" +
				"varying vec3 vColor;\n" +
				"varying vec3 vNormal;\n" +
				"varying float vIsReflect;\n" +
				"varying float vAmbIntensity;\n" +
				"\n" +
				"const float COLOR_UNIT = 1.0 / 255.0;\n" +
				"void main() {\n" +
				"    gl_Position = uMatrix * aPosition;\n" +
				"    vNormal = mat3(uMatrixMV) * aNormal;\n" +
				"    if (uIsPrimitive) {\n" +
				"        vColor = uColor.r < -0.5 ? vec3(aColorData * COLOR_UNIT) : uColor;\n" +
				"        vIsReflect = 1.0;\n" +
				"        vAmbIntensity = uAmbIntensity;\n" +
				"    } else {\n" +
				"        vColor = vec3(aColorData * COLOR_UNIT);\n" +
				"        vIsReflect = aMaterial[1];\n" +
				"        vAmbIntensity = aMaterial[0] > 0.5 ? uAmbIntensity : -1.0;\n" +
				"    }\n" +
				"}\n";

		private static final String FRAGMENT =
				"precision mediump float;\n" +
				"uniform sampler2D uSphereUnit;\n" +
				"uniform vec2 uSphereSize;\n" +
				"uniform vec3 uLightDir;\n" +
				"uniform float uDirIntensity;\n" +
				"uniform float uToonThreshold;\n" +
				"uniform float uToonHigh;\n" +
				"uniform float uToonLow;\n" +
				"varying vec3 vColor;\n" +
				"varying vec3 vNormal;\n" +
				"varying float vIsReflect;\n" +
				"varying float vAmbIntensity;\n" +
				"\n" +
				"void main() {\n" +
				"    if (vAmbIntensity < -0.5) {\n" +
				"        gl_FragColor = vec4(vColor, 1.0);\n" +
				"        return;\n" +
				"    }\n" +
				"    vec4 spec = uSphereSize.x < -0.5 || vIsReflect < 0.5 ?\n" +
				"        vec4(0.0) : texture2D(uSphereUnit, (normalize(vNormal).xy + 1.0) * 0.5 * uSphereSize);\n" +
				"    float lambert_factor = max(dot(normalize(vNormal), uLightDir), 0.0);\n" +
				"    float light = min(vAmbIntensity + uDirIntensity * lambert_factor, 1.0);\n" +
				"    if (uToonThreshold > -0.5) {\n" +
				"        light = light < uToonThreshold ? uToonLow : uToonHigh;\n" +
				"    }\n" +
				"    gl_FragColor = vec4(vColor * light + spec.rgb, 1.0);\n" +
				"}\n";

		int uSphereUnit;
		int uSphereSize;
		int uColor;
		int uIsPrimitive;
		int uToonThreshold;
		int uToonHigh;
		int uToonLow;

		Color() {
			super(VERTEX, FRAGMENT);
		}

		@Override
		protected void getLocations() {
			aPosition = glGetAttribLocation(id, "aPosition");
			aNormal = glGetAttribLocation(id, "aNormal");
			aColorData = glGetAttribLocation(id, "aColorData");
			aMaterial = glGetAttribLocation(id, "aMaterial");
			uColor = glGetUniformLocation(id, "uColor");
			uMatrix = glGetUniformLocation(id, "uMatrix");
			uMatrixMV = glGetUniformLocation(id, "uMatrixMV");
			uAmbIntensity = glGetUniformLocation(id, "uAmbIntensity");
			uDirIntensity = glGetUniformLocation(id, "uDirIntensity");
			uLightDir = glGetUniformLocation(id, "uLightDir");
			uSphereUnit = glGetUniformLocation(id, "uSphereUnit");
			uSphereSize = glGetUniformLocation(id, "uSphereSize");
			uIsPrimitive = glGetUniformLocation(id, "uIsPrimitive");
			uToonThreshold = glGetUniformLocation(id, "uToonThreshold");
			uToonHigh = glGetUniformLocation(id, "uToonHigh");
			uToonLow = glGetUniformLocation(id, "uToonLow");
		}

		void setColor(int rgb) {
			float r = (rgb >> 16 & 0xff) / 255.0f;
			float g = (rgb >> 8 & 0xff) / 255.0f;
			float b = (rgb & 0xff) / 255.0f;
			glUniform3f(uColor, r, g, b);
		}

		void setToonShading(Effect3D effect) {
			boolean enable = effect.mShading == Effect3D.TOON_SHADING && effect.isToonShading;
			glUniform1f(uToonThreshold, enable ? effect.mToonThreshold : -1.0f);
			glUniform1f(uToonHigh, effect.mToonHigh);
			glUniform1f(uToonLow, effect.mToonLow);
		}

		void disableUniformColor() {
			glUniform3f(uColor, -1.0f, -1.0f, -1.0f);
		}

		void bindMatrices(float[] mvp, float[] mv) {
			glUniformMatrix4fv(uMatrix, 1, false, mvp, 0);
			glUniformMatrix4fv(uMatrixMV, 1, false, mv, 0);
		}
	}

	static final class Simple extends Program {
		private static final String VERTEX =
				"attribute vec4 a_position;\n" +
				"attribute vec2 a_texcoord0;\n" +
				"varying vec2 v_texcoord0;\n" +
				"void main() {\n" +
				"    gl_Position = a_position;\n" +
				"    v_texcoord0 = a_texcoord0;\n" +
				"}\n";

		private static final String FRAGMENT =
				"precision mediump float;\n" +
				"uniform sampler2D sampler0;\n" +
				"varying vec2 v_texcoord0;\n" +
				"void main() {\n" +
				"    gl_FragColor = texture2D(sampler0, v_texcoord0);\n" +
				"}\n";

		int aTexture;
		int uTextureUnit;

		Simple() {
			super(VERTEX, FRAGMENT);
		}

		protected void getLocations() {
			aPosition = glGetAttribLocation(id, "a_position");
			aTexture = glGetAttribLocation(id, "a_texcoord0");
			uTextureUnit = glGetUniformLocation(id, "sampler0");
		}
	}

	static final class Tex extends Program {
		private static final String VERTEX =
				"uniform mat4 uMatrix;\n" +
				"uniform mat4 uMatrixMV;\n" +
				"uniform bool uIsTransparency;\n" +
				"uniform bool uIsPrimitive;\n" +
				"uniform float uAmbIntensity;\n" +
				"attribute vec4 aPosition;\n" +
				"attribute vec3 aNormal;\n" +
				"attribute vec2 aColorData;\n" +
				"attribute vec3 aMaterial;\n" +
				"varying vec2 vTexture;\n" +
				"varying vec3 vNormal;\n" +
				"varying float vIsTransparency;\n" +
				"varying float vIsReflect;\n" +
				"varying float vAmbIntensity;\n" +
				"\n" +
				"void main() {\n" +
				"    gl_Position = uMatrix * aPosition;\n" +
				"    vNormal = mat3(uMatrixMV) * aNormal;\n" +
				"    if (uIsPrimitive) {\n" +
				"        vIsTransparency = uIsTransparency ? 1.0 : 0.0;\n" +
				"        vIsReflect = 1.0;\n" +
				"        vAmbIntensity = uAmbIntensity;\n" +
				"    } else {\n" +
				"        vIsTransparency = aMaterial[2];\n" +
				"        vIsReflect = aMaterial[1];\n" +
				"        vAmbIntensity = aMaterial[0] > 0.5 ? uAmbIntensity : -1.0;\n" +
				"    }\n" +
				"    vTexture = aColorData;\n" +
				"}\n";

		private static final String FRAGMENT =
				"precision mediump float;\n" +
				"uniform sampler2D uTextureUnit;\n" +
				"uniform sampler2D uSphereUnit;\n" +
				"uniform vec2 uTexSize;\n" +
				"uniform vec3 uColorKey;\n" +
				"uniform vec2 uSphereSize;\n" +
				"uniform vec3 uLightDir;\n" +
				"uniform float uDirIntensity;\n" +
				"uniform float uToonThreshold;\n" +
				"uniform float uToonHigh;\n" +
				"uniform float uToonLow;\n" +
				"varying vec2 vTexture;\n" +
				"varying vec3 vNormal;\n" +
				"varying float vIsTransparency;\n" +
				"varying float vIsReflect;\n" +
				"varying float vAmbIntensity;\n" +
				"\n" +
				"const vec3 COLORKEY_ERROR = vec3(0.5 / 255.0);\n" +
				"\n" +
				"void main() {\n" +
				"    vec4 color = texture2D(uTextureUnit, (floor(vTexture) + 0.5) / uTexSize);\n" +
				"    if (vIsTransparency > 0.5 && all(lessThan(abs(color.rgb - uColorKey), COLORKEY_ERROR)))\n" +
				"            discard;\n" +
				"    if (vAmbIntensity < -0.5) {\n" +
				"        gl_FragColor = vec4(color.rgb, 1.0);\n" +
				"        return;\n" +
				"    }\n" +
				"    vec4 spec = uSphereSize.x < -0.5 || vIsReflect < 0.5 ?\n" +
				"        vec4(0.0) : texture2D(uSphereUnit, (normalize(vNormal).xy + 1.0) * 0.5 * uSphereSize);\n" +
				"    float lambert_factor = max(dot(normalize(vNormal), uLightDir), 0.0);\n" +
				"    float light = min(vAmbIntensity + uDirIntensity * lambert_factor, 1.0);\n" +
				"    if (uToonThreshold > -0.5) {\n" +
				"        light = light < uToonThreshold ? uToonLow : uToonHigh;\n" +
				"    }\n" +
				"    gl_FragColor = vec4(color.rgb * light + spec.rgb, 1.0);\n" +
				"}\n";

		int uTextureUnit;
		int uTexSize;
		int uIsTransparency;
		int uSphereUnit;
		int uSphereSize;
		int uIsPrimitive;
		int uToonThreshold;
		int uToonHigh;
		int uToonLow;
		int uColorKey;

		Tex() {
			super(VERTEX, FRAGMENT);
		}

		@Override
		protected int loadShader(int type, String shaderCode) {
			if (Boolean.getBoolean("micro3d.v3.texture.filter")) {
				shaderCode = "#define FILTER\n" + shaderCode;
			}
			return super.loadShader(type, shaderCode);
		}

		protected void getLocations() {
			aPosition = glGetAttribLocation(id, "aPosition");
			aNormal = glGetAttribLocation(id, "aNormal");
			aColorData = glGetAttribLocation(id, "aColorData");
			aMaterial = glGetAttribLocation(id, "aMaterial");
			uTextureUnit = glGetUniformLocation(id, "uTextureUnit");
			uSphereUnit = glGetUniformLocation(id, "uSphereUnit");
			uTexSize = glGetUniformLocation(id, "uTexSize");
			uColorKey = glGetUniformLocation(id, "uColorKey");
			uSphereSize = glGetUniformLocation(id, "uSphereSize");
			uMatrix = glGetUniformLocation(id, "uMatrix");
			uMatrixMV = glGetUniformLocation(id, "uMatrixMV");
			uIsTransparency = glGetUniformLocation(id, "uIsTransparency");
			uAmbIntensity = glGetUniformLocation(id, "uAmbIntensity");
			uDirIntensity = glGetUniformLocation(id, "uDirIntensity");
			uLightDir = glGetUniformLocation(id, "uLightDir");
			uIsPrimitive = glGetUniformLocation(id, "uIsPrimitive");
			uToonThreshold = glGetUniformLocation(id, "uToonThreshold");
			uToonHigh = glGetUniformLocation(id, "uToonHigh");
			uToonLow = glGetUniformLocation(id, "uToonLow");
		}

		void enableTexUnit() {
			glActiveTexture(GL_TEXTURE0);
			glUniform1i(uTextureUnit, 0);
		}

		void setTransparency(int transparent) {
			glUniform1i(uIsTransparency, transparent);
		}

		void setTex(Texture tex) {
			if (tex != null) {
				glUniform2f(uTexSize, tex.width, tex.height);
				glUniform3fv(uColorKey, 1, tex.getColorKey());
				glBindTexture(GL_TEXTURE_2D, tex.getId());
			} else {
				glUniform2f(uTexSize, 256, 256);
				glBindTexture(GL_TEXTURE_2D, 0);
			}
		}

		void setToonShading(Effect3D effect) {
			boolean enable = effect.mShading == Effect3D.TOON_SHADING && effect.isToonShading;
			glUniform1f(uToonThreshold, enable ? effect.mToonThreshold / 255.0f : -1.0f);
			glUniform1f(uToonHigh, effect.mToonHigh / 255.0f);
			glUniform1f(uToonLow, effect.mToonLow / 255.0f);
		}

		void bindMatrices(float[] mvp, float[] mv) {
			glUniformMatrix4fv(uMatrix, 1, false, mvp, 0);
			glUniformMatrix4fv(uMatrixMV, 1, false, mv, 0);
		}
	}

	static class Sprite extends Program {
		private static final String VERTEX =
				"attribute vec4 aPosition;\n" +
				"attribute vec2 aColorData;\n" +
				"varying vec2 vTexture;\n" +
				"\n" +
				"void main() {\n" +
				"    gl_Position = aPosition;\n" +
				"    vTexture = aColorData;\n" +
				"}\n";

		private static final String FRAGMENT =
				"precision mediump float;\n" +
				"uniform vec2 uTexSize;\n" +
				"uniform sampler2D uTexUnit;\n" +
				"uniform vec3 uColorKey;\n" +
				"uniform bool uIsTransparency;\n" +
				"varying vec2 vTexture;\n" +
				"\n" +
				"const vec3 COLORKEY_ERROR = vec3(0.5 / 255.0);\n" +
				"\n" +
				"void main() {\n" +
				"    vec4 color = texture2D(uTexUnit, (floor(vTexture) + 0.5) / uTexSize);\n" +
				"    if (uIsTransparency && all(lessThan(abs(color.rgb - uColorKey), COLORKEY_ERROR)))\n" +
				"            discard;\n" +
				"    gl_FragColor = vec4(color.rgb, 1.0);\n" +
				"}\n";

		int uTexUnit;
		int uTexSize;
		int uIsTransparency;
		int uColorKey;

		Sprite() {
			super(VERTEX, FRAGMENT);
		}

		@Override
		protected int loadShader(int type, String shaderCode) {
			if (Boolean.getBoolean("micro3d.v3.texture.filter")) {
				shaderCode = "#define FILTER\n" + shaderCode;
			}
			return super.loadShader(type, shaderCode);
		}

		protected void getLocations() {
			aPosition = glGetAttribLocation(id, "aPosition");
			aColorData = glGetAttribLocation(id, "aColorData");
			uTexUnit = glGetUniformLocation(id, "uTexUnit");
			uTexSize = glGetUniformLocation(id, "uTexSize");
			uColorKey = glGetUniformLocation(id, "uColorKey");
			uIsTransparency = glGetUniformLocation(id, "uIsTransparency");
		}
	}
}
