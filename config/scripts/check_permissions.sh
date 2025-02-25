#!/bin/bash

# Define paths, expected permissions and ownership
FOLDER1="/data/dspace"
FOLDER2="/data/dspace-angular-dspace-8.1"
EXPECTED_PERM_FOLDER1="755"
EXPECTED_PERM_FOLDER2="775"
EXPECTED_USER_FOLDER1="dspace"
EXPECTED_GROUP_FOLDER1="dspace"
EXPECTED_USER_FOLDER2="seyediana1"
EXPECTED_GROUP_FOLDER2="dspace"

# Expected permissions for files within folders
EXPECTED_PERM_FILES1="775"  # Expected permission for files in folder1
EXPECTED_PERM_FILES2="775"  # Expected permission for files in folder2

# Output file
WARNING_FILE="/tmp/perm_warning"
rm -f $WARNING_FILE

# Function to check a folder and its contents
check_folder() {
    local folder="$1"
    local expected_perm_folder="$2"
    local expected_user_folder="$3"
    local expected_group_folder="$4"
    local expected_perm_files="$5"
    local has_issues=0
    
    # Check folder permissions and ownership
    actual_perm=$(stat -c "%a" "$folder")
    actual_user=$(stat -c "%U" "$folder")
    actual_group=$(stat -c "%G" "$folder")
    
    if [ "$actual_perm" != "$expected_perm_folder" ] || [ "$actual_user" != "$expected_user_folder" ] || [ "$actual_group" != "$expected_group_folder" ]; then
        if [ "$has_issues" -eq 0 ]; then
            echo "WARNING: Permissions/ownership issues detected!" > $WARNING_FILE
            has_issues=1
        fi
        
        echo "Folder ($folder):" >> $WARNING_FILE
        echo "  Permissions: Expected $expected_perm_folder, Actual $actual_perm" >> $WARNING_FILE
        echo "  Owner: Expected $expected_user_folder, Actual $actual_user" >> $WARNING_FILE
        echo "  Group: Expected $expected_group_folder, Actual $actual_group" >> $WARNING_FILE
    fi
    
    # Check permissions and ownership of files within the folder
    while IFS= read -r file; do
        actual_file_perm=$(stat -c "%a" "$file")
        actual_file_user=$(stat -c "%U" "$file")
        actual_file_group=$(stat -c "%G" "$file")
        
        if [ "$actual_file_perm" != "$expected_perm_files" ] || [ "$actual_file_user" != "$expected_user_folder" ] || [ "$actual_file_group" != "$expected_group_folder" ]; then
            if [ "$has_issues" -eq 0 ]; then
                echo "WARNING: Permissions/ownership issues detected!" > $WARNING_FILE
                has_issues=1
            fi
            
            if [ ! -f "$WARNING_FILE.files_$folder" ]; then
                echo "Files in $folder with incorrect permissions/ownership:" >> $WARNING_FILE
                touch "$WARNING_FILE.files_$folder"
            fi
            
            filename=$(basename "$file")
            echo "  - $filename:" >> $WARNING_FILE
            
            if [ "$actual_file_perm" != "$expected_perm_files" ]; then
                echo "      Permissions: Expected $expected_perm_files, Actual $actual_file_perm" >> $WARNING_FILE
            fi
            
            if [ "$actual_file_user" != "$expected_user_folder" ]; then
                echo "      Owner: Expected $expected_user_folder, Actual $actual_file_user" >> $WARNING_FILE
            fi
            
            if [ "$actual_file_group" != "$expected_group_folder" ]; then
                echo "      Group: Expected $expected_group_folder, Actual $actual_file_group" >> $WARNING_FILE
            fi
        fi
    done < <(find "$folder" -type f -maxdepth 1)
    
    # Clean up temporary files
    rm -f "$WARNING_FILE.files_$folder"
    
    return $has_issues
}

# Check both folders and their contents
folder1_issues=$(check_folder "$FOLDER1" "$EXPECTED_PERM_FOLDER1" "$EXPECTED_USER_FOLDER1" "$EXPECTED_GROUP_FOLDER1" "$EXPECTED_PERM_FILES1")
folder2_issues=$(check_folder "$FOLDER2" "$EXPECTED_PERM_FOLDER2" "$EXPECTED_USER_FOLDER2" "$EXPECTED_GROUP_FOLDER2" "$EXPECTED_PERM_FILES2")

# If issues were found and we're running from cron (not boot), notify active users
if [ -s "$WARNING_FILE" ] && [ "$PPID" != "1" ]; then
    # Find all active terminal sessions and send message
    for user_tty in $(who | awk '{print $2}'); do
        echo "ATTENTION: Folder permission issues detected. Type 'cat /tmp/perm_warning' for details." > /dev/$user_tty
    done
    
    # Alternative: use notify-send for desktop users (requires X session)
    # for user in $(who | awk '{print $1}' | sort -u); do
    #    XAUTHORITY=/home/$user/.Xauthority DISPLAY=:0 sudo -u $user notify-send -u critical "Permission Alert" "Folder permission issues detected"
    # done
fi

# If no issues were found, make sure warning file is removed
if [ ! -s "$WARNING_FILE" ]; then
    rm -f "$WARNING_FILE"
fi
