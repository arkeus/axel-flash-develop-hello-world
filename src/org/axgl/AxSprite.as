package org.axgl {
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	
	import org.axgl.render.AxQuad;
	import org.axgl.resource.AxResource;
	import org.axgl.util.AxAnimation;
	import org.axgl.util.AxCache;

	/**
	 * An <code>AxSprite</code> is the entity that makes up most game objects. You can load an image, rotate it, change
	 * the color, move it, and more. Game objects that will be visible on screen should extend this class.
	 */
	public class AxSprite extends AxModel {
		/** The quad defining the size of this sprite, to help with rendering. */
		public var quad:AxQuad;
		/** Whether or not the buffer for this sprite needs to be recalculated. */
		public var dirty:Boolean;
		/** The location in the texture where the current frame resides. */
		protected var uvOffset:Vector.<Number>;
		
		/**
		 * The x and y coordinations of this sprite on the screen. A sprite in the upper left corner of the screen
		 * will have coordinates 0, 0 -- regardless of where the camera is currently at. 
		 */
		public var screen:AxPoint;
		
		/**
		 * TODO: after all this time?
		 * 
		 * @default "always"
		 */
		protected var debugColor:Vector.<Number>;

		/** The current animation this sprite is playing. */
		public var animation:AxAnimation;
		/** All registered animations of this sprite. This is a map from animation name to animation. */
		protected var animations:Object;
		/** Read-only. The delay between switching frames used to play the current animation. */
		protected var animationDelay:Number;
		/** Read-only. The timer for playing the current animation. */
		protected var animationTimer:Number;

		/** The current frame of the animation. If an animation is not currently playing, the currently showing frame. */
		public var frame:uint = 0;
		/** The number of frames per row in the loaded texture. */
		public var framesPerRow:uint;
		/** The width of the frame for this entity. Used for animation. */
		public var frameWidth:Number;
		/** The height of the frame for this entity. Used for animation. */
		public var frameHeight:Number;

		/**
		 * The direction this sprite is facing. If <code>facing</code> is equal to <code>flip</code>, the sprite
		 * will be flipped horizontally. Set <code>flip</code> to <code>NONE</code> to disable this behavior.
		 * 
		 * @default RIGHT
		 */
		public var facing:uint = RIGHT;
		/**
		 * The direction that causes this sprite to be flipped horizontally.
		 * 
		 * @default LEFT
		 * 
		 * @see #facing
		 */
		public var flip:uint = LEFT;

		/**
		 * Creates a new sprite at the given position. Loads the image in graphic using the given frameWidth and frameHeight. If
		 * frameWidth or frameHeight are 0, then the entire image is treated as a single frame. If you do not pass a graphic here,
		 * you should call <code>load</code> with your graphic, otherwise it will use the default Axel logo as the sprite.
		 * 
		 * @param x The initial x value of this sprite.
		 * @param y The initial y value of this sprite.
		 * @param graphic The embedded graphic to use for this sprite.
		 * @param frameWidth The width of each frame in the embedded graphic.
		 * @param frameHeight The height of each frame in the embedded graphic.
		 */
		public function AxSprite(x:Number, y:Number, graphic:Class = null, frameWidth:uint = 0, frameHeight:uint = 0) {
			super(x, y, VERTEX_SHADER, FRAGMENT_SHADER, 4, "AxSprite");

			matrix = new Matrix3D;
			scale = new AxPoint(1, 1);
			debugColor = Vector.<Number>([1, 0, 0, 1]);
			colorTransform.fixed = true;
			uvOffset = new Vector.<Number>(4, true);
			screen = new AxPoint;

			quad = null;
			dirty = true;

			animations = new Object;

			if (graphic != null) {
				load(graphic, frameWidth, frameHeight);
			}
		}

		/**
		 * Loads a new graphic for this sprite with the specified frame width and height.
		 * 
		 * @param graphic The graphic to load for this sprite.
		 * @param frameWidth The width of each frame in the graphic.
		 * @param frameHeight The height of each frame in the graphic.
		 *
		 * @return The sprite instance.
		 */
		public function load(graphic:*, frameWidth:uint = 0, frameHeight:uint = 0):AxSprite {
			this.frameWidth = frameWidth;
			this.frameHeight = frameHeight;
			calculateTexture(graphic);
			width = this.frameWidth;
			height = this.frameHeight;
			framesPerRow = Math.max(1, Math.floor(texture.rawWidth / width));
			pivot.x = width / 2;
			pivot.y = height / 2;
			quad = new AxQuad(this.frameWidth, this.frameHeight, this.frameWidth / texture.width, this.frameHeight / texture.height);
			frame = 0;
			return this;
		}
		
		/**
		 * Creates a new graphic for this sprite, filling it with a single color. Use this to create solid colored square
		 * graphics quickly and easily. Color should include alpha and be in the format 0xAARRGGBB.
		 * 
		 * @param width Width of the sprite.
		 * @param height Height of the sprite.
		 * @param color Color of the sprite, including alpha, in the foramt 0xAARRGGBB.
		 *
		 * @return The sprite instance.
		 */
		public function create(width:uint, height:uint, color:uint):AxSprite {
			var bitmap:BitmapData = new BitmapData(width, height, true, color);
			return load(bitmap, width, height);
		}

		/**
		 * Snape kills dumbledore.
		 * 
		 * @param red
		 * @param green
		 * @param blue
		 * @param alpha
		 */
		public function setDebugColor(red:Number, green:Number, blue:Number, alpha:Number = -1):void {
			debugColor[RED] = red;
			debugColor[GREEN] = green;
			debugColor[BLUE] = blue;
			if (alpha != -1) {
				debugColor[ALPHA] = alpha;
			}
		}

		/**
		 * Kills snape.
		 */
		public function resetDebugColor():void {
			if (solid) {
				debugColor[RED] = 1;
				debugColor[GREEN] = 0;
				debugColor[BLUE] = 0;
				debugColor[ALPHA] = 1;
			} else {
				debugColor[RED] = 0;
				debugColor[GREEN] = 1;
				debugColor[BLUE] = 0;
				debugColor[ALPHA] = 1;
			}
		}

		/**
		 * Sets the bounding box for this sprite. This is a helpfer method to set the width, height, and offset values
		 * all at once.
		 * 
		 * <p>If an entity is loaded with an image that is 100x100, you can use <code>offset, width, and height</code> to
		 * change the bounding box that will affect collisions. The width and height determine the size of the bounding box,
		 * and offset determines how far to the right and down the upper left corner of the bounding box is.</p>
		 * 
		 * @param width The width of the bounding box.
		 * @param height The height of the bounding box.
		 * @param offsetX The x offset of the bounding box.
		 * @param offsetY The y offset of the bounding box.
		 *
		 * @return The instance of this sprite.
		 */
		public function bounds(width:uint, height:uint, offsetX:int, offsetY:int):AxSprite {
			this.width = width;
			this.height = height;
			this.offset.x = offsetX;
			this.offset.y = offsetY;
			return this;
		}

		/**
		 * Calculates the vertex buffer for this sprite, using the cached version if another identical vertex buffer exists.
		 */
		private function calculateVertexBuffer():void {
			vertexBuffer = AxCache.vertexBuffer(frameWidth, frameHeight, 1, 1);
		}

		/**
		 * Calculates the debug vertex buffer for this sprite, using the cached version if another identical vertex buffer exists.
		 */
		private function calculateDebugVertexBuffer():void {
			//debugVertexBuffer = AxCache.debugVertexBuffer(width, height, 1, 1);//uvSize.x, uvSize.y);
		}

		/**
		 * Calculates the texture for the passed graphic. If the same graphic was used to create a texture, pulls it from the
		 * cache. Otherwise, creates a new texture and uploads it to the GPU. Note that that performance reasons, you should
		 * always upload a graphic whose dimensions are a multiple of 2 (eg. 128x64). If you don't, the graphic must be copied
		 * to a temporary bitmap that is a power of 2, before being converted to a texture.
		 * 
		 * @param graphic The graphic to create the texture from.
		 */
		private function calculateTexture(graphic:*):void {
			texture = AxCache.texture(graphic);
			if (frameWidth == 0 || frameHeight == 0) {
				frameWidth = texture.rawWidth;
				frameHeight = texture.rawHeight;
			}
		}

		/**
		 * Adds a new animation to this sprite. The <code>name</code> of the animation is what you will use to access it via the <code>animate</code>
		 * function. The <code>frames</code> is an array that lists the frames of the animation in the order they will play. <code>Framerate</code> is
		 * how fast the animation will play; it indicates how many frames will be played per second. If you have a 5 frame animation with a
		 * framerate of 10, it will play the animation twice per second. The <code>looped</code> parameter indicates whether or not this
		 * animation should stop at the end of the animation, or if it should loop repeatedly.
		 * 
		 * @param name The name of the animation.
		 * @param frames The array of frames that make up the animation.
		 * @param framerate The framerate at which the animation should play.
		 * @param looped Whether or not the animation should loop.
		 *
		 * @return The sprite instance.
		 */
		public function addAnimation(name:String, frames:Array, framerate:uint = 15, looped:Boolean = true):AxSprite {
			animations[name] = new AxAnimation(name, frames, framerate < 1 ? 15 : framerate, looped);
			return this;
		}

		/**
		 * Tells this sprite to immediately start playing the animation that you passed. If that animation is already playing,
		 * this call will do nothing. If you want to stop the animation and instead show a static frame, use the <code>show</code>
		 * method instead.
		 * 
		 * @param name The name of the animation to play.
		 *
		 * @return The sprite instance.
		 */
		public function animate(name:String):AxSprite {
			if ((animation == null || (animation != null && animation.name != name)) && animations[name] != null) {
				animation = animations[name];
				animationDelay = 1 / animation.framerate;
				animationTimer = animationDelay;
				frame = 0;
			}
			return this;
		}
		
		/**
		 * Stops the current animation (if one is playing), and tells the sprite to show a static frame. That frame does
		 * not need to be part of any animation.
		 * 
		 * @param frame The frame that should show.
		 *
		 * @return The sprite instance.
		 */
		public function show(frame:uint):AxSprite {
			this.animation = null;
			this.frame = frame;
			return this;
		}

		/**
		 * Calculates the helper variables required to draw the current frame of this sprite.
		 */
		private function calculateFrame():void {
			if (animation != null) {
				animationTimer += Ax.dt;
				while (animationTimer >= animationDelay) {
					animationTimer -= animationDelay;
					if (frame + 1 < animation.frames.length || animation.looped) {
						frame = (frame + 1) % animation.frames.length;
					}
					uvOffset[0] = (animation.frames[frame] % framesPerRow) * quad.uvWidth;
					uvOffset[1] = Math.floor(animation.frames[frame] / framesPerRow) * quad.uvHeight;
				}
			} else {
				uvOffset[0] = (frame % framesPerRow) * quad.uvWidth;
				uvOffset[1] = Math.floor(frame / framesPerRow) * quad.uvHeight;
			}
		}

		/**
		 * @inheritDoc
		 */
		override public function get left():Number {
			return x;
		}

		/**
		 * @inheritDoc
		 */
		override public function get top():Number {
			return y;
		}

		/**
		 * @inheritDoc
		 */
		override public function get right():Number {
			return x + width * scale.x;
		}

		/**
		 * @inheritDoc
		 */
		override public function get bottom():Number {
			return y + height * scale.y;
		}

		/**
		 * @inheritDoc
		 */
		override public function update():void {
			super.update();

			screen.x = (x - Ax.camera.x) * scroll.x;
			screen.y = (y - Ax.camera.y) * scroll.y;
			calculateFrame();
		}

		/**
		 * Builds a vertex buffer for the given quad.
		 * 
		 * @param quad The quad defining the vertexes for which to build the vertex buffer.
		 */
		public function buildVertexBuffer(quad:AxQuad):void {
			if (indexBuffer == null) {
				indexBuffer = SPRITE_INDEX_BUFFER;
			}

			vertexBuffer = AxCache.vertexBuffer(quad.width, quad.height, quad.uvWidth, quad.uvHeight);
			triangles = 2;
		}

		/**
		 * @inheritDoc
		 */
		override public function draw():void {
			if (texture == null) {
				load(AxResource.ICON);
			}
			
			if (dirty) {
				buildVertexBuffer(quad);
				dirty = false;
			}

			if (screen.x > Ax.width || screen.y > Ax.height || screen.x + frameWidth < 0 || screen.y + frameHeight < 0) {
				return;
			}
			
			colorTransform[RED] = color.red;
			colorTransform[GREEN] = color.green;
			colorTransform[BLUE] = color.blue;
			colorTransform[ALPHA] = color.alpha;

			matrix.identity();

			if (angle != 0) {
				matrix.appendRotation(angle, Vector3D.Z_AXIS, pivot);
			}

			var sx:Number = x - offset.x;
			var sy:Number = y - offset.y;
			var scalex:Number = scale.x * facing == flip ? -1 : 1;
			var scaley:Number = scale.y;
			var cx:Number = Ax.camera.x // / Ax.scale;
			var cy:Number = Ax.camera.y // / Ax.scale;
			if (scalex != 1 || scaley != 1) {
				matrix.appendTranslation(-pivot.x, -pivot.y, 0);
				matrix.appendScale(scalex, scaley, 1);
				matrix.appendTranslation(pivot.x + sx - cx * scroll.x, pivot.y + sy - cy * scroll.y, 0);
			} else {
				matrix.appendTranslation(sx - cx * scroll.x, sy - cy * scroll.y, 0);
			}

			matrix.append(zooms ? Ax.camera.projection : Ax.camera.baseProjection);

			Ax.context.setProgram(shader.program);
			Ax.context.setTextureAt(0, texture.texture);
			Ax.context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
			Ax.context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, matrix, true);
			Ax.context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, uvOffset);
			Ax.context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, colorTransform);
			Ax.context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			Ax.context.setVertexBufferAt(1, vertexBuffer, 2, Context3DVertexBufferFormat.FLOAT_2);
			Ax.context.drawTriangles(indexBuffer, 0, triangles);
			Ax.context.setTextureAt(0, null);
			Ax.context.setVertexBufferAt(0, null, 0, Context3DVertexBufferFormat.FLOAT_2);
			Ax.context.setVertexBufferAt(1, null, 2, Context3DVertexBufferFormat.FLOAT_2);
			
			if (countTris) {
				Ax.debugger.tris += triangles;
			}

			/*Ax.context.setProgram(AxRenderer.spriteShader);
			Ax.context.setTextureAt(0, texture.texture);
			Ax.context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
			Ax.context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, matrix, true);
			Ax.context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, uv);
			Ax.context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, transform);
			Ax.context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			Ax.context.setVertexBufferAt(1, vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			Ax.context.drawTriangles(AxRenderer.indexBuffer, 0, AxRenderer.indexData.length / 3);
	
			if (Ax.showBounds) {
				if (debugVertexBuffer == null) {
					calculateDebugVertexBuffer();
				}
	
				matrix.prependTranslation(Math.round(bounds.x), Math.round(bounds.y), 0);
	
				Ax.context.setProgram(AxRenderer.debugShader);
				Ax.context.setTextureAt(0, null);
				Ax.context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 5, matrix, true);
				Ax.context.setVertexBufferAt(0, debugVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
				Ax.context.setVertexBufferAt(1, null, 3, Context3DVertexBufferFormat.FLOAT_2);
				Ax.context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, debugColor);
				Ax.context.drawTriangles(AxRenderer.debugIndexBuffer, 0, AxRenderer.debugIndexData.length / 3);
				resetDebugColor();
			}*/
		}
		
		override public function dispose():void {
			//quad = null;
			screen = null;
			uvOffset = null;
			debugColor = null;
			if (animation != null) {
				animation.dispose();
			}
			animation = null;
			animations = null;
			color = null;
		}

		/**
		 * The vertex shader for this sprite.
		 */
		private static const VERTEX_SHADER:Array = [
			"m44 vt0, va0, vc0",
			"add v1, va1, vc4",
			"mov op, vt0"
		];

		/**
		 * The fragment shader for this sprite.
		 */
		private static const FRAGMENT_SHADER:Array = [
			"tex ft0, v1, fs0 <2d,nearest,mipnone>",
			"mul oc, fc0, ft0"
		];

		/**
		 * A static sprite index buffer that all AxSprites will use.
		 */
		public static var SPRITE_INDEX_BUFFER:IndexBuffer3D;

		{
			SPRITE_INDEX_BUFFER = Ax.context.createIndexBuffer(6);
			SPRITE_INDEX_BUFFER.uploadFromVector(Vector.<uint>([0, 1, 2, 1, 2, 3]), 0, 6);
		}
	}
}
