# ImageKit assignment

## Problem Statement

You get an opportunity to work on a database design similar to the one that is currently being used in ImageKit’s media library as well.
We need to create a directory structure with folders and files in it. For creating this, you need to store the information about these folders and files in any database of your choice. The folder structure would look something like this
/ (root)

- Folder1
    - File1.png
    - File2.png
- Folder2
    - SubFolder1
    - SubFolder2
        - File3.jpg
        - File4.txt

Along with the above directory structure information, we should also be able to store information
about a file, like

- Format
- Size in KBs
- Dimensions

## Expectations

1. The database design / schema
2. The queries or any other code or logic that would need to be run on that database to achieve the following tasks: 
a. Insert a new folder or file at any level (root or inside a folder)
b. Get list of all files reverse sorted by date
c. Find the total size of a folder (like total size of files contained in Folder2 which would include size of files File3.jpg and File4.txt)
d. Delete a folder
e. Search by filename
f. Search for files with name “File1” and format = PNG
g. Rename SubFolder2 to NestedFolder2

---

## Approach

To implement the database design for the file system I am going to use MySQL. The details of the files and folders can be stored easily in using this database. But the problem arises when we have to keep in mind the hierarchical order of the folders and files.

The file structure system is inherently hierarchical  and conventional relational Database Systems like MySQL are not readily suitable  for these type of data. But still there are mainly two ways we can store file system in a relational Database like MySQL.

1. **The Adjacency List Model**
    
    In the adjacency list model, each item in the table contains a pointer to its parent. The topmost element, in this case /*root*, has a NULL value for its parent. The adjacency list model has the advantage of being quite simple, it is easy to see the parent child relationship. The main limitation of such an approach is that you need one self-join for every level in the hierarchy, and performance will naturally degrade with each level added as the joining grows in complexity. To get all the children of parent you must know the depth to which it can go and write the query according to that, which will obviously different for parent nodes have different depths of nodes under them.
    
2. **The Nested Set Model**
    
    This is the approach that i picked to implement the required design. In this approach along with the data of files and folder we will maintain the parent child relationship. A parent will store the pointers lft and rgt in such a way that all its children have their lft and rgt pointers within it's parent range.
    
    ![Representation of the Nested Set Model](ImageKit%20assignment%20388e1195b5b1447eb22c564c9983f272/Blank_diagram.jpeg)
    
    Representation of the Nested Set Model
    

## Solution:

The solution is in the form of SQL queries. One can run them by passing correct values to the variables which are declared in the queries.

## 1. Schemas and Initial Root folder

```sql
CREATE SCHEMA `file_system` ;

CREATE TABLE `tb_folders` (
    `folder_id` int NOT NULL AUTO_INCREMENT,
    `folder_name` varchar(256) NOT NULL,
    `folder_path` varchar(256) NOT NULL,
    `parent_id` int NULL DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`folder_id`)
) ENGINE=InnoDB;

CREATE TABLE `tb_files` (
    `file_id` int NOT NULL AUTO_INCREMENT,
    `file_name` varchar(256) NOT NULL,
    `file_path` varchar(256) NOT NULL,
    `file_format` varchar(256) NOT NULL,
    `file_size` int NOT NULL COMMENT 'in KB',
    `folder_id` int NOT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`file_id`),
    KEY `file_name` (`file_name`(256)) USING BTREE,
    KEY `file_format` (`file_format`(256)) USING BTREE,
    KEY `created_at` (`created_at`) USING BTREE,
    FOREIGN KEY (`folder_id`) REFERENCES `tb_folders`(`folder_id`)  ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `tb_file_structure` (
    `id` int NOT NULL AUTO_INCREMENT,
    `folder_id` int NULL DEFAULT NULL,
    `file_id` int NULL DEFAULT NULL,
    `parent_id` int NULL DEFAULT NULL,
    `lft` int NULL default NULL,
    `rgt` int NULL default NULL,
     PRIMARY KEY (`id`),
     FOREIGN KEY (`folder_id`) REFERENCES `tb_folders`(`folder_id`)  ON DELETE CASCADE,
     FOREIGN KEY (`file_id`) REFERENCES `tb_files`(`file_id`)  ON DELETE CASCADE
)ENGINE=InnoDB;

INSERT INTO `tb_folders` (`folder_name`, `folder_path`, `parent_id`) VALUES ('root', '/root', NULL);
INSERT INTO `tb_file_structure` (`folder_id`, `file_id`, `parent_id`, `lft`, `rgt`) VALUES (1, NULL, NULL, 1, 2 );
```

![The Schema](ImageKit%20assignment%20388e1195b5b1447eb22c564c9983f272/Untitled.png)

The Schema

## 2. a. Insert a new folder or file at any level (root or inside a folder)

```sql
-- Inserting a folder

SET autocommit=0;

LOCK TABLES tb_file_structure WRITE, tb_folders WRITE;

SET @folderName = 'Folder1';
SET @parentId = 1;

SELECT @parentPath := folder_path FROM tb_folders WHERE folder_id = @parentId;
SET @folderPath = CONCAT(@parentPath , '/', @folderName);

INSERT INTO `tb_folders` (`folder_name`, `folder_path`, `parent_id`) 
VALUES (@folderName, @folderPath, @parentId);

SET @folderId = LAST_INSERT_ID() ;

SELECT @myRight := rgt FROM tb_file_structure WHERE folder_id = @parentId;

UPDATE tb_file_structure SET rgt = rgt + 2 WHERE rgt >= @myRight;
UPDATE tb_file_structure SET lft = lft + 2 WHERE lft >= @myRight;

INSERT INTO tb_file_structure(folder_id, parent_id, lft, rgt) VALUES(@folderId, @parentId, @myRight, @myRight + 1);
COMMIT;
UNLOCK TABLES;

-- Inserting a file

SET autocommit=0;
LOCK TABLES tb_file_structure WRITE, tb_files WRITE, tb_folders READ;
SET @folderId = 2;
SET @fileName = 'file1';
SET @fileFormat = 'txt';
SET @fileSize = 1024;

SELECT @parentPath := folder_path FROM tb_folders WHERE folder_id = @folderId;
SET @filePath = CONCAT(@parentPath, '/', @fileName, '.', @fileFormat);

INSERT INTO `tb_files` (`file_name`, `file_path`, `file_format`, `file_size`, `folder_id`) 
VALUES (@fileName, @filePath, @fileFormat, @fileSize, @folderId);

SET @fileId = LAST_INSERT_ID() ;

SELECT @myRight := rgt FROM tb_file_structure WHERE folder_id = @folderId;

UPDATE tb_file_structure SET rgt = rgt + 2 WHERE rgt >= @myRight;
UPDATE tb_file_structure SET lft = lft + 2 WHERE lft >= @myRight;

INSERT INTO tb_file_structure(file_id, parent_id, lft, rgt) VALUES(@fileId, @folderId, @myRight, @myRight + 1);

COMMIT;
UNLOCK TABLES;
```

## 2. b. Get list of all files reverse sorted by date

```sql
SELECT * FROM tb_files ORDER BY created_at DESC;
```

## 2. c. Find the total size of a folder (like total size of files contained in Folder2 which would include size of files File3.jpg and File4.txt)

```sql
SET @folderId = 1;
SELECT @lftVal := lft, @rgtVal := rgt FROM tb_file_structure WHERE folder_id = @folderId
SELECT COALESCE(SUM(file_size), 0) as folderSize FROM tb_files WHERE file_id IN (
    SELECT file_id FROM tb_file_structure WHERE rgt = lft + 1 
    AND lft > @lftVal 
    AND rgt < @rgtVal
    AND file_id IS NOT NULL
)
```

## 2. d. Delete a folder

```sql

SET autocommit=0;
LOCK TABLES tb_file_structure WRITE,  tb_files WRITE,  tb_folders WRITE;

SET @folderId = 4;
SELECT @myLeft := lft, @myRight := rgt, @myWidth := rgt - lft + 1
FROM tb_file_structure WHERE folder_id = @folderId;

DELETE FROM tb_folders WHERE folder_id IN (
    SELECT folder_id FROM tb_file_structure WHERE lft >= @myLeft AND rgt <= @myRight
);

UPDATE tb_file_structure SET rgt = rgt - @myWidth WHERE rgt > @myRight;
UPDATE tb_file_structure SET lft = lft - @myWidth WHERE lft > @myRight;

COMMIT;
UNLOCK TABLES;
```

## 2. e.  Search by filename

```sql
SET @fileName = 'file1';
SELECT * FROM tb_files WHERE file_name LIKE @fileName;
```

## 2. f. Search for files with name “File1” and format = PNG

```sql
SET @fileName = 'File1';
SET @fileFormat = 'txt';
SELECT * FROM tb_files WHERE file_name LIKE @fileName AND file_format LIKE @fileFormat;
```

## 2.g. Rename SubFolder2 to NestedFolder2

```sql
SET @newFolderName = 'NestedFolder2';
SET @oldFolderName = 'SubFolder2';
SET @folderId = 2;
UPDATE tb_folders SET folder_name = @newFolderName 
WHERE folder_name = @oldFolderName OR folder_id = @folderId
```