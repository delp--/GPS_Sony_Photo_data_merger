############
# Funcs taken from - 
# https://mnaoumov.wordpress.com/2015/01/11/get-exif-metadata-with-powershell/
#############

function PSUsing {
    param
    (
        [IDisposable] $disposable,
        [ScriptBlock] $scriptBlock
    )
 
    try {
        & $scriptBlock
    }
    finally {
        if ($disposable -ne $null) {
            $disposable.Dispose()
        }
    }
}

function Get-ExifProperty {
    param
    (
        [string] $ImagePath,
        [int] $ExifTagCode
    )
 
    $fullPath = (Resolve-Path $ImagePath).Path
 
    PSUsing ($fs = [System.IO.File]::OpenRead($fullPath)) `
    {
        write-host ("fs: $fs")
        PSUsing ($image = [System.Drawing.Image]::FromStream($fs, $false, $false)) `
        {
            if (-not $image.PropertyIdList.Contains($ExifTagCode)) {
                return $null
            }
 
            $propertyItem = $image.GetPropertyItem($ExifTagCode)
            $valueBytes = $propertyItem.Value
            $value = [System.Text.Encoding]::ASCII.GetString($valueBytes) -replace "`0$"
            return $value
        }
    }
    write-host ("Error -> dropping to return null")
    return $null
}

# Taken from https://www.loc.gov/preservation/digital/formats/content/tiff_tags.shtml
$ExifTagCode_DateTimeOriginal = 0x9003

function Get-DateTaken {
    param
    (
        [string] $ImagePath
    )
 
    $str = Get-ExifProperty -ImagePath $ImagePath -ExifTagCode $ExifTagCode_DateTimeOriginal
 
    if ($str -eq $null) {
        return $null
    }
 
    $dateTime = [DateTime]::MinValue
    if ([DateTime]::TryParseExact($str, "yyyy:MM:dd HH:mm:ss", $null, [System.Globalization.DateTimeStyles]::None, [ref] $dateTime)) {
        return $dateTime
    }
 
    return $null
}

############
# END
#############


# SD Card location
$inputDir = "H:\"

# Where to output files with details.
# Folder structure will be 
# - year
# -- m_d_mmm
# --- type (eg photos)
$outputDir = "E:\"


# Get every file under the input dir, including sub dirs
$files = Get-ChildItem $inputDir -file -Recurse


# Create reusable func for chaning dir based on type
function copyFileOfType($file, $type) {
    # find when it was created
    $dateCreated = $file.CreationTime
     write-host ("dateCreated: $dateCreated")
    # Build up a path to where the file should be copied to (e.g. 1_2_Jan) use numbers for ordering and inc month name to make reading easier.
    # make sure the day is in the format to be ordered, as in 
    $folderName = $outputDir + $dateCreated.Year + "\" + $dateCreated.Month + "_" + $dateCreated.Day + "_" + (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($dateCreated.Month) + "\" + $type + "\"
	
    # Check if the folder exists, if it doesn't create it
    if (-not (Test-Path $folderName)) { 
        new-item $folderName -itemtype directory        
    }
    # build up the full path inc filename
    $filePath = $folderName + $fileName
    # If it's not already copied, copy it
    if (-not (Test-Path $filePath)) { 
        Copy-Item $file.FullName -Destination $filePath
        echo ("Copied " + $file.FullName)        
    }
}


foreach ($f in $files) {   
    # get the files name  
    $fileName = $f.Name
    echo "( [IO.Path]::GetExtension($fileName)"

    if (( [IO.Path]::GetExtension($fileName) -eq '.jpg' ) -or ([IO.Path]::GetExtension($fileName) -eq '.arw' ) -or ([IO.Path]::GetExtension($fileName) -eq '.mp4' )) {    
        #get date of the file created
        $date = Get-DateTaken -ImagePath $f.FullName 
        

        if ( [IO.Path]::GetExtension($fileName) -eq '.jpg' ) {
            echo ("copied: " + $f.FullName)
            copyFileOfType -file $f -type "photos"
        }
        elseif ( [IO.Path]::GetExtension($fileName) -eq '.arw') {
            copyFileOfType -file $f -type "raw"
        }
        elseif ( [IO.Path]::GetExtension($fileName) -eq '.mp4') {
            copyFileOfType -file $f -type "movies"
        }
        else {
            #Do nothing
        }  
        echo " "
    }  
}
