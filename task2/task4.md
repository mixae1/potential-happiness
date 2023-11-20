```bash
anoth@moth:~/Desktop$ touch file1
anoth@moth:~/Desktop$ touch file2
anoth@moth:~/Desktop$ touch -t 199001010000.00 file2
anoth@moth:~/Desktop$ ls -l
total 0
-rw-rw-r-- 1 anoth anoth 0 ноя 17 13:29 file1
-rw-rw-r-- 1 anoth anoth 0 янв  1  1990 file2
anoth@moth:~/Desktop$ chmod 760 file2
anoth@moth:~/Desktop$ mkdir -p dir1/dir2/dir3
anoth@moth:~/Desktop$ chmod -R 760 dir1
anoth@moth:~/Desktop$ ls -lR dir1
dir1:
total 4
drwxrw---- 3 anoth anoth 4096 ноя 17 13:30 dir2

dir1/dir2:
total 4
drwxrw---- 2 anoth anoth 4096 ноя 17 13:30 dir3

dir1/dir2/dir3:
total 0
anoth@moth:~/Desktop$ ls -ld dir1
drwxrw---- 3 anoth anoth 4096 ноя 17 13:30 dir1
anoth@moth:~/Desktop$ cp file1 dir1/dir2/dir3/
anoth@moth:~/Desktop$ mv file2 dir1/dir2/dir3/
anoth@moth:~/Desktop$ ls -r
file1  dir1
anoth@moth:~/Desktop$ ls -R
.:

dir1  file1

./dir1:
dir2

./dir1/dir2:
dir3

./dir1/dir2/dir3:
file1  file2
anoth@moth:~/Desktop$ ls -ld dir1
drwxrw---- 3 anoth anoth 4096 ноя 17 13:30 dir1
anoth@moth:~/Desktop$ file dir1
dir1: directory
anoth@moth:~/Desktop$ file -i dir1
dir1: inode/directory; charset=binary
anoth@moth:~/Desktop$ date +%s
1700217221
anoth@moth:~/Desktop$ rm -dr *
anoth@moth:~/Desktop$ ls
```