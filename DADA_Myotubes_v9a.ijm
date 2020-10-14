//--------------------------------------------------------------------------------
// MACRO TO PERFORM AUTOMATED MYOTUBE / NUCLEI ANALYSIS
//--------------------------------------------------------------------------------
//
// INPUT: Macro requests a directory containing TIF stacks with Green (myotubes) and blue (nuclei).
//
// CHANGELOG:
// v1: First commit. Basic file handling and reporting of parameters to the log. Also writes out a results table
// v2: Processing A directory of files, output all to a results table and log window
// v3: Proper implementation of DEBUG mode for batch processing, log window only in DEBUG
// v4: Added option to run just nuclei segmentation via choice - Uses 8bit Nuclei tifs
// v5: Added option to run just nuclei segmentation via choice - Uses RGB tifs, added more debug info
// v6: Removed Debug mode (causing problems with output).
// v7: Corrected typo in test for TIF extension, added in minimal debugMode, altered threshold of 
//		nuclei (slightly undercounts as a result), catches zero nuclei fields
// v8: Integrated debug option into dialog. Hardcoded myotube thresholding (grudgingly). Corrected CreateSelection error when there are no myotubes objects in a mask (ver 8a).
// v9: Due to changes in acquisition which breaks thresholding, apply a Bandpass FFT to correct uneven illumination
//
//
//									- Dave Mason [dnmason@liv.ac.uk] March 2015
//														Latest Revision Nov 2015
//--------------------------------------------------------------------------------
//
//-- Offer the choice between Full analysis or just nuclei counting (cancel quits macro):
  arrOpts=newArray("Nuclei","Myotube Analysis");
  Dialog.create("Analysis Type?");
  Dialog.addChoice("Analysis Type",arrOpts,"Nuclei");
  Dialog.setInsets(20,50,0); //-- Add a bit more space
  Dialog.addCheckbox("Debug Mode?", false)
  Dialog.show();
  choice = Dialog.getChoice();
  debugMode = Dialog.getCheckbox(); //-- false and zero are equivalencies so no need to parse

if (debugMode==0) {setBatchMode(true);}

//-- Code to implement batch processing
//-- Ask for source directory
dir1 = getDirectory("Choose source directory");

//Returns an array containing the names of files in a directory
dirList = getFileList(dir1);

//--Initialise in case there are no valid files in directory	
rowNum=0;

//-- Loop through file list
for (i=0; i<dirList.length; i++){
//-- Form a path to the file using input directory and filename
	path = dir1+dirList[i];

// Import file
//-- Check is a tif using endsWith()
if (endsWith(dirList[i],"tif")) {

open(path);
c0=getImageID;
if (debugMode==1) {print("Opening File: "+dirList[i]+" with imageID = "+c0);}
//---- Get and parse date and time string

     getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString = " " + year + "-";
	if (month<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+month+"-";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-";
    if (hour<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+hour;
    if (minute<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+minute;
    if (second<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+second;


title = File.name;

//-- check is an RGB stack
if (bitDepth==24) {
	
// Split Images and label
run("Split Channels");
  c3=getImageID; c2=c3+1; c1=c3+2;
// c3 nuclei      c2 myo   c1 blank

// NUCLEI	 -----------------------------------
selectImage(c3);
rename("Original Nuclei");
//-- Added a bandpass filter to correct for uneven illumination (ver 9a)
run("Bandpass Filter...", "filter_large=100 filter_small=0 suppress=None tolerance=5 autoscale");
setAutoThreshold("Triangle dark"); //-- Li doesn't work if there are low numbers of saturated nuclei
setOption("BlackBackground", true);
run("Convert to Mask");
run("Watershed");
run("Analyze Particles...", "size=150-900 show=Masks display"); //-- Increased ceiling in v7
run("Invert LUT");
c4=getImageID; //-- Mask of Nuclei
rename("nucMask");

totNuclei=nResults; //-- If there's no results, nResults=0 (obviously) but there's no Results table

//-- Close Results table
if (totNuclei>0) {
selectWindow("Results");
run("Close"); 
}

if (choice=="Myotube Analysis") { //-- Do the rest of the analysis -----------------------------------------------------------------------------

// MYOTUBES -----------------------------------
  selectImage(c2);
  rename("Myotubes");
//-- Added a bandpass filter to correct for uneven illumination (ver 9)
run("Bandpass Filter...", "filter_large=100 filter_small=0 suppress=None tolerance=5 autoscale");

//setAutoThreshold("Li dark"); //-- DOesn't work if you have no myotubes
setThreshold(55, 255);
setOption("BlackBackground", true);
run("Convert to Mask");

run("Dilate");		//-- Attempt to deal with holes
run("Fill Holes"); 	//-- May cause problems with overlapping myotubes
//-- Get rid of junk
run("Analyze Particles...", "size=200-Infinity show=Masks"); 
run("Invert LUT");
rename("myoMask");
c5=getImageID; //-- Refined Myotube Mask

//-- Measure Area
getDimensions(w, h, c, s, f);
setAutoThreshold("Default dark");
run("Create Selection");
List.setMeasurements;//-- Equivalent to measure (with all "Set Measurements" Options)
myoMaskArea = List.getValue("Area");
//-- If there are no myotubes, then CreateSelection returns a full image size. If this is the case make MyoMaskArea zero.
if (myoMaskArea==w*h) {myoMaskArea=0;}
resetThreshold();
run("Select None");

// Logical AND, make a new window
imageCalculator("AND create", "nucMask","myoMask");
c6=getImageID; //-- Nuclei in myotubes
rename("Overlap All");

run("Analyze Particles...", "size=150-Infinity show=Nothing display");
grnNuclei=nResults;
//-- Close Results table if it's been opened
if (grnNuclei>0) {
selectWindow("Results");
run("Close"); 
}
//-- Refine masks to BIG myotubes
selectImage(c5);
run("Analyze Particles...", "size=2000-Infinity show=Masks");
run("Invert LUT");
c6=getImageID; //-- Big myotubes mask
rename("bigMyoMask");

//-- Measure Area
setAutoThreshold("Default dark");
run("Create Selection");
List.setMeasurements;//-- Equivalent to measure (with all "Set Measurements" Options)
bigMyoMaskArea = List.getValue("Area");
//-- If there are no myotubes, then CreateSelection returns a full image size. If this is the case make MyoMaskArea zero.
if (bigMyoMaskArea==w*h) {bigMyoMaskArea=0;}
resetThreshold();
run("Select None");
// Logical AND, make a new window
imageCalculator("AND create", "nucMask","bigMyoMask");
c7=getImageID; //-- Nuclei in BIG myotubes
rename("Overlap Myotubes");
run("Analyze Particles...", "size=150-Infinity show=Nothing display");
grnNucleiMyo=nResults;
//-- Close Results table
if (grnNucleiMyo>0) {
selectWindow("Results");
run("Close"); 
}
			} //-- Close Myotube Analysis

if (choice=="Myotube Analysis") {
//-- Output to a results table-----------------------------
if (isOpen("MyoResults")) {
selectWindow("MyoResults");
IJ.renameResults("Results");
}
rowNum=nResults;
setResult("TimeStamp",rowNum,TimeString);
setResult("File",rowNum,title);
setResult("Total Nuclei",rowNum,totNuclei);
setResult("Total Myotube Area",rowNum,myoMaskArea); //-- added in v3
setResult("Nuclei in Green Cells",rowNum,grnNuclei);
setResult("Nuclei in Myotubes",rowNum,grnNucleiMyo);
setResult("Big Myotube Area",rowNum,bigMyoMaskArea);
setResult("Myotube pixels per nuclei",rowNum,bigMyoMaskArea/grnNucleiMyo);
setResult("Fusion Index",rowNum,grnNucleiMyo/grnNuclei);
setResult("Differentiation Index",rowNum,grnNuclei/totNuclei);
updateResults();
selectWindow("Results");
IJ.renameResults("MyoResults");
} else {
//-- Output to a results table-----------------------------
if (isOpen("MyoResults")) {
selectWindow("MyoResults");
IJ.renameResults("Results");
}
rowNum=nResults;
setResult("TimeStamp",rowNum,TimeString);
setResult("File",rowNum,title);
setResult("Total Nuclei",rowNum,totNuclei);
updateResults();
selectWindow("Results");
IJ.renameResults("MyoResults");	
}
//-- Misc DEBUG options before loop close
if (debugMode==1) {run("Tile");} //-- display masks
if (debugMode==1) { waitForUser("Click OK to continue");} //-- Halt with a non-modal dialog so you can check stuff
if (debugMode==1) { close("*");} //-- close the images so none are left over for the next round
//if (debugMode==1) {i=dirList.length;} //-- from v5 good to test processing


		} //-- not 24bit (3x8bit RGB)
	} //-- not a Tif
} //-- For loop (dirList)

//-- Finish with dialog to alert the user that processing is complete.
if (rowNum==0) {
waitForUser("No valid files found in directory: "+dir1);		
} else {
waitForUser("Done processing "+(rowNum+1)+" files.");	
}
