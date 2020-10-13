#include <stdio.h>
#include <stdlib.h>

#include "color.h"
#include "display.h"
#include "options.h"
#include "types.h"

void
display(struct ccm_list *colors, struct Options *opts)
{
	char colorbar[32 + 1];
	char colorstr[1000]; /* shut up -Wformat-overflow warnings */

	for (struct ccm_list *i = colors->next; i != NULL; i = i->next) {
		struct RGB *c = (struct RGB *) i->data;

		sprintf((char *) &colorbar,
			"\033[48;2;%i;%i;%im\033[K\033[0m", c->r, c->g, c->b);

		if (opts->display == HEXRGB) {
			sprintf((char *) &colorstr, "#%02x%02x%02x\t",
				c->r, c->g, c->b);
		} else if (opts->display == DECRGB) {
			sprintf((char *) &colorstr, "%03i,%03i,%03i\t",
				c->r, c->g, c->b);
		} else if (opts->display == HSV) {
			struct HSV *hsv = hsv_from_rgb(c);
			sprintf((char *) &colorstr, "hsv(%.2f,%.2f,%.2f)\t",
				hsv->h, hsv->s, hsv->v);
		} else {
			colorstr[0] = '\0';
		}

		if (opts->display_color) {
			printf("%s%s\n", (char *) &colorstr,
				(char *) &colorbar);
		} else {
			printf("%s\n", (char *) &colorstr);
		}
	}
}
