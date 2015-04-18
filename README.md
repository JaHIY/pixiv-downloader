# pixiv-downloader

### Environment:

 * shell
 * [xidel](http://videlibri.sourceforge.net/xidel.html) (Arch Linux users can install it from [AUR](https://aur.archlinux.org/packages/xidel/))

### How to use

rename `config.example` to `config` and set `your account` and `password` in it, and then you may run:
``` bash
$ main.sh < pixiv_url.txt
```

`pixiv_url.txt` is a list of pixiv url, for example:
```
http://www.pixiv.net/member_illust.php?mode=medium&illust_id=1234567
http://www.pixiv.net/member_illust.php?mode=medium&illust_id=2345678
```
