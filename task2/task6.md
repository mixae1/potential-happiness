```bash
anoth@moth:~/Desktop$ free | grep 'Mem'
Mem:         4000916      849520     1790504       40572     1360892     2885028

anoth@moth:~/Desktop$ netstat -tln | grep 'LISTEN '
tcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN     
tcp6       0      0 ::1:631                 :::*                    LISTEN     
anoth@moth:~/Desktop$ netstat -ln | grep 'LISTEN '
tcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN     
tcp6       0      0 ::1:631                 :::*                    LISTEN  

anoth@moth:~/Desktop$ mkdir dir

anoth@moth:~/Desktop$ time for i in {0..99}; do mkdir "dir/sub_dir${i}"; done
real	0m0,282s
user	0m0,183s
sys	0m0,081s

anoth@moth:~/Desktop$ du -sh dir
404K	dir

anoth@moth:~/Desktop$ rm -rd *
```