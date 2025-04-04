/* tag.c */
char *did_set_tagfunc(optset_T *args);
void free_tagfunc_option(void);
int set_ref_in_tagfunc(int copyID);
void set_buflocal_tfu_callback(buf_T *buf);
int do_tag(char_u *tag, int type, int count, int forceit, int verbose);
void tag_freematch(void);
void do_tags(exarg_T *eap);
int find_tags(char_u *pat, int *num_matches, char_u ***matchesp, int flags, int mincount, char_u *buf_ffname);
void free_tag_stuff(void);
int get_tagfname(tagname_T *tnp, int first, char_u *buf);
void tagname_free(tagname_T *tnp);
void tagstack_clear_entry(taggy_T *item);
int expand_tags(int tagnames, char_u *pat, int *num_file, char_u ***file);
int get_tags(list_T *list, char_u *pat, char_u *buf_fname);
void get_tagstack(win_T *wp, dict_T *retdict);
int set_tagstack(win_T *wp, dict_T *d, int action);
/* vim: set ft=c : */
