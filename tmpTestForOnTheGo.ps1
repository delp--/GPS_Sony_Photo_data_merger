############
# Funcs taken from - 
# https://mnaoumov.wordpress.com/2015/01/11/get-exif-metadata-with-powershell/
#############

function PSUsing
{
    param
    (
        [IDisposable] $disposable,
        [ScriptBlock] $scriptBlock
    )
 
    try
    {
        & $scriptBlock
    }
    finally
    {
        if ($disposable -ne $null)
        {
            $disposable.Dispose()
        }
    }
}

function Get-ExifProperty
{
    param
    (
        [string] $ImagePath,
        [int] $ExifTagCode
    )
 
    $fullPath = (Resolve-Path $ImagePath).Path
 
    PSUsing ($fs = [System.IO.File]::OpenRead($fullPath)) `
    {
        PSUsing ($image = [System.Drawing.Image]::FromStream($fs, $false, $false)) `
        {
            if (-not $image.PropertyIdList.Contains($ExifTagCode))
            {
                return $null
            }
 
            $propertyItem = $image.GetPropertyItem($ExifTagCode)
            $valueBytes = $propertyItem.Value
            $value = [System.Text.Encoding]::ASCII.GetString($valueBytes) -replace "`0$"
            return $value
        }
    }
}

# Taken from https://www.loc.gov/preservation/digital/formats/content/tiff_tags.shtml
$ExifTagCode_DateTimeOriginal = 0x9003

function Get-DateTaken
{
    param
    (
        [string] $ImagePath
    )
 
    $str = Get-ExifProperty -ImagePath $ImagePath -ExifTagCode $ExifTagCode_DateTimeOriginal
 
    if ($str -eq $null)
    {
        return $null
    }
 
    $dateTime = [DateTime]::MinValue
    if ([DateTime]::TryParseExact($str, "yyyy:MM:dd HH:mm:ss", $null, [System.Globalization.DateTimeStyles]::None, [ref] $dateTime))
    {
        return $dateTime
    }
 
    return $null
}

############
# END
#############


# SD Card location
$inputDir = "E:\GitHub\TestData\tmp\"

# Where to output files with details.
# Folder structure will be 
# - year
# -- m_d_mmm
# --- type (eg photos)
$outputDir = "E:\GitHub\TestData\MemoryCardCopyOutput\"

# Open GPS xml direct from eTrex 
$gpxFile = "E:\GitHub\TestData\Current.gpx"
# Pull out xml into var
[xml]$xmlTrackData = Get-Content -Path $gpxFile

# eTrex stores routes inside trk nodes. Pull out all trk's 
$tracks = $xmlTrackData.gpx.trk

# set up array to store every data point
$dataPoints = [System.Collections.ArrayList]::new()

# There can be multiple tracks per file
$tracks | ForEach-Object {

    # Each track can have multiple segments (trkseg) and each segment can have multiple points   
    $_.trkseg.trkpt | ForEach-Object {
        [void]$dataPoints.Add($_)
    }
}

# Get every file under the input dir, including sub dirs
$files = Get-ChildItem $inputDir -file -Recurse


# Create reusable func for chaning dir based on type
function copyFileOfType($file, $type) {
    # find when it was created
    $dateCreated = $file.CreationTime
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
        write-host("Copied " + $file.FullName )
        #echo ("Copied " + $file.FullName)        
    }
}


# Return a GPS point if one is found close enough to the time the photo was taken
function getSelectedPoint($fileDate) {
    $dataPoints | ForEach-Object {    
        # As an example the time node in xml will look like (note Z is UTC time)
        # <time>2021-03-30T20:12:22Z</time>
        # This will be converted into you OS timezone with the below
        $dataPointTime = Get-Date $_.time

        $diffInTime = New-TimeSpan –Start $dataPointTime –End $fileDate
        $diffTimeInSeconds = $diffInTime.TotalSeconds

        if( $diffTimeInSeconds -lt 0) { # Strip -ve values
            $diffTimeInSeconds = $diffTimeInSeconds * -1    
        }
        
        if(( $diffTimeInSeconds -lt $lowestDiffInTime ) -or ($lowestDiffInTime -eq $null)) {
            $lowestDiffInTime = $diffTimeInSeconds
            $selectPoint = $_
        }
    } 

    # If the time diff isn't set or it's to great to be accurate do not return a point
    if(( $lowestDiffInTime -eq $null ) -or ($lowestDiffInTime -gt 180)) {
        write-host ("Point not found, time diff: $lowestDiffInTime using fileDate: $fileDate")
     return $null
    }    
    return $selectPoint
}

#This would be good to enter as a param - for now it's hard coded.
# My camera is set to UTC/GMT time, so when I take photos in BST they are an hour behind
# This makes sure GPS tracked time and photo time are synced up
$photosTakenInBSTTimeZoneButCameraRecordingInUTC = $false

function getDateFromFile($file) {
    $shellObject = New-Object -ComObject Shell.Application
    $directoryObject = $shellObject.NameSpace( $file.Directory.FullName )
    $fileObject = $directoryObject.ParseName( $file.Name )

    $property = 'Date taken'
    for(
       $index = 5;
       $directoryObject.GetDetailsOf( $directoryObject.Items, $index ) -ne $property;
       ++$index ) { }

    $value = $directoryObject.GetDetailsOf( $fileObject, $index )
    $format= "dd/MM/yyyy HH:mm";
    $formattedDateString = $value -replace '[^\p{L}\p{Nd}\:\/\ ]', ''

    return $date1=[System.DateTime]::ParseExact($formattedDateString,$format, $null)
}

foreach ($f in $files) {   
    # get the files name  
    $fileName = $f.Name

    if (( [IO.Path]::GetExtension($fileName) -eq '.jpg' ) -or ([IO.Path]::GetExtension($fileName) -eq '.arw' ) -or ([IO.Path]::GetExtension($fileName) -eq '.mp4' )) {    
       
        if([IO.Path]::GetExtension($fileName) -eq '.mp4' ) {        
            $date = $f.LastWriteTime
         } else {
            $date = getDateFromFile -file $f
         }

       #get date of the file created
       # $date2 = Get-DateTaken -ImagePath $f.FullName 

       # $date3 = Get-LastWriteTime -ImagePath $f.FullName 
        write-host( "date used for file: $fileName is: $date")

        if( $date -ne $null) {                  
            if($photosTakenInBSTTimeZoneButCameraRecordingInUTC) {
                $date = $date.AddHours(1)
            }
            write-host( "Final Date for: $fileName is: $date")
            $point = getSelectedPoint -fileDate $date
                

            # Only add a GPS point if one is set
            if( $point -ne $null ) {   
                $lat = $point.lat
                $lon = $point.lon
                $fullName = $f.FullName
                 write-host( "Using point lat: $lat, lon: $lon, fullName: $fullName ")
                #$combLat = '-GPSLatitude*=' + $point.lat
                #$combLon = '-GPSLongitude*=' + $point.lon
                .\exiftool.exe `-GPSLatitude*=$lat `-GPSLongitude*=$lon $fullName -overwrite_original_in_place               
             }
         } else {         
            write-host( "Warning the date of the image ($fileName) is null, this will not work")
         }

        if ( [IO.Path]::GetExtension($fileName) -eq '.jpg' ) {
            write-host ("copied: " + $f.FullName)
            copyFileOfType -file $f -type "photos"
        }
        elseif ( [IO.Path]::GetExtension($fileName) -eq '.arw') {
            write-host ("copied: " + $f.FullName)
            copyFileOfType -file $f -type "raw"
        }
        elseif ( [IO.Path]::GetExtension($fileName) -eq '.mp4') {
            write-host ("copied: " + $f.FullName)
            copyFileOfType -file $f -type "movies"
        }
        else {
            #Do nothing
        }  
        echo " "
    }  
}
