package org.axgl.render {

	/**
	 * A class describing the red, green, blue, and alpha components of a color.
	 */
	public class AxColor {
		/** The red component, between 0 and 1. */
		public var r:Number;
		/** The green component, between 0 and 1. */
		public var g:Number;
		/** The blue component, between 0 and 1. */
		public var b:Number;
		/** The alpha component, between 0 and 1. */
		public var a:Number;
		
		/**
		 * Creates a new color with the given components, defaults to completely opaque white.
		 * 
		 * @param red The red component, between 0 and 1.
		 * @param green The green component, between 0 and 1.
		 * @param blue The blue component, between 0 and 1.
		 * @param alpha The alpha component, between 0 and 1.
		 *
		 */
		public function AxColor(red:Number = 1, green:Number = 1, blue:Number = 1, alpha:Number = 1) {
			this.r = red;
			this.g = green;
			this.b = blue;
			this.a = alpha;
		}
	}
}
