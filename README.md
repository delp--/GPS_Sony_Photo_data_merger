# GPS_Sony_Photo_data_merger
This is a powershell script to copy files from the camera SD card, while cross referencing a GPS tracking devices data points and adding the GPS points to the photos.

# How to use the script
The script has a handful of hard coded values as this is at the moment something that will just work for me!  
If you wish to run it then you will have to edit the following - 
* `$inputDir` # SD Card location
  * This is the location that your photos will come from. In my case I had this set to the drive that was assigned to my SD card when it was inserted.
* `$outputDir`- This is where you wish the root to be for the copied to folder.  As in all the photos from the input will be copied here. It will have a strucutre such as outputDir\year\m_d_mmm\file_type\\*.files (eg E:\photos\2021\4_14_Apr\raw\DSC01427.ARW) *.ARW's are Sony's RAW photo files
* `$gpxFile` #This is the exact location of hte *.gpx file.
* `$photosTakenInBSTTimeZoneButCameraRecordingInUTC = $true`. This will depend on your timezone. Time and timezones are a pain! I've put this in for ease. You will need to look at whatever data you have in your gpx file and match that up with your photo's date taken value and work out the offset required.  This aid me to make sure that the files and gpx times match.
  * This will make it into a TODO, in terms of making is simple to use. It will be nice to be able to view and pick any photo that you know where it was taken, then use that as an index/offset for time.

