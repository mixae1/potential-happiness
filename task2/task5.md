```bash
anoth@moth:~/Desktop$ mkdir public
anoth@moth:~/Desktop$ mkdir private
anoth@moth:~/Desktop$ mkdir private/.hidden_dir
anoth@moth:~/Desktop$ mkdir public/'New Folder'
anoth@moth:~/Desktop$ touch public/'New Folder'/file.txt
anoth@moth:~/Desktop$ cd public/New\ Folder/
anoth@moth:~/Desktop/public/New Folder$ ls
file.txt
anoth@moth:~/Desktop/public/New Folder$ ln -s file.txt soft-link-file.txt
anoth@moth:~/Desktop/public/New Folder$ cd ../../
anoth@moth:~/Desktop$ ls -lRa
.:
total 16
drwxr-xr-x  4 anoth anoth 4096 ноя 17 13:49 .
drwxr-x--- 14 anoth anoth 4096 ноя 17 13:23 ..
drwxrwxr-x  3 anoth anoth 4096 ноя 17 13:49 private
drwxrwxr-x  3 anoth anoth 4096 ноя 17 13:49 public

./private:
total 12
drwxrwxr-x 3 anoth anoth 4096 ноя 17 13:49 .
drwxr-xr-x 4 anoth anoth 4096 ноя 17 13:49 ..
drwxrwxr-x 2 anoth anoth 4096 ноя 17 13:49 .hidden_dir

./private/.hidden_dir:
total 8
drwxrwxr-x 2 anoth anoth 4096 ноя 17 13:49 .
drwxrwxr-x 3 anoth anoth 4096 ноя 17 13:49 ..

./public:
total 12
drwxrwxr-x 3 anoth anoth 4096 ноя 17 13:49  .
drwxr-xr-x 4 anoth anoth 4096 ноя 17 13:49  ..
drwxrwxr-x 2 anoth anoth 4096 ноя 17 13:49 'New Folder'

'./public/New Folder':
total 8
drwxrwxr-x 2 anoth anoth 4096 ноя 17 13:49 .
drwxrwxr-x 3 anoth anoth 4096 ноя 17 13:49 ..
-rw-rw-r-- 1 anoth anoth    0 ноя 17 13:49 file.txt
lrwxrwxrwx 1 anoth anoth    8 ноя 17 13:49 soft-link-file.txt -> file.txt
anoth@moth:~/Desktop$ rm -dr *
anoth@moth:~/Desktop$ ^C
anoth@moth:~/Desktop$ 
```