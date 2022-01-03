
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


-- * a Insert data

-- * i.folder 
     -- * required params: folder_name, parent_id, 


     -- * Example: adding a folder to root folder
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

--  * ii. file 
     --  * required params: folder_id to which folder the file is going to be written, 
     -- * file_name, file_format, parent_id, file_format, file_size
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


-- * b. Get list of all files reverse sorted by date
    SELECT * FROM tb_files ORDER BY created_at DESC;

-- * c Find the total size of a folder (like total size of files contained in Folder2 which would include size of files File3.jpg and File4.txt)

SET @folderId = 1;
SELECT @lftVal := lft, @rgtVal := rgt FROM tb_file_structure WHERE folder_id = @folderId
SELECT COALESCE(SUM(file_size), 0) as folderSize FROM tb_files WHERE file_id IN (
    SELECT file_id FROM tb_file_structure WHERE rgt = lft + 1 
    AND lft > @lftVal 
    AND rgt < @rgtVal
    AND file_id IS NOT NULL
)

-- * d. Delete a folder

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

-- * e. Search by filename

    SET @fileName = 'file1';
    SELECT * FROM tb_files WHERE file_name LIKE @fileName;

-- * f. Search for files with name “File1” and format = PNG

SET @fileName = 'File1';
SET @fileFormat = 'txt';
SELECT * FROM tb_files WHERE file_name LIKE @fileName AND file_format LIKE @fileFormat;


-- * g. Rename SubFolder2 to NestedFolder2

SET @newFolderName = 'NestedFolder2';
SET @oldFolderName = 'SubFolder2';
SET @folderId = 2;
UPDATE tb_folders SET folder_name = @newFolderName 
WHERE folder_name = @oldFolderName OR folder_id = @folderId 