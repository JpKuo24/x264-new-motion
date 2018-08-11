/* i_var -> int, f_var -> float, p_var -> pixel (~int, uint8_t for 8-bit vid).

*/


/* pointer over mb of the frame to be compressed */
pixel *p_fenc[3]; /* y,u,v */
/* pointer to the actual source frame, not a block copy */
pixel *p_fenc_plane[3];

/* pointer over mb of the frame to be reconstructed  */
pixel *p_fdec[3];

/* pointer over mb of the references */
int i_fref[2];
/* [12]: yN, yH, yV, yHV, (NV12 ? uv : I444 ? (uN, uH, uV, uHV, vN, ...)) */ 
pixel *p_fref[2][X264_REF_MAX*2][12];
pixel *p_fref_w[X264_REF_MAX*2]; /* weighted fullpel luma */
/* fref stride */
int     i_stride[3];

from x264_t.mb.pic