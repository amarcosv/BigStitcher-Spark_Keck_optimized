// Expects arguments: "/path/to/data/ xml_name"
args = getArgument();
args = split(args, " ");

if (args.length < 2) {
    print("Usage: Fiji --headless -macro define_dataset.ijm '/path/to/data/ xml_filename'");
    eval("script", "System.exit(1);");
}

basePath = args[0];
xmlName = args[1];

// Ensure path ends with separator
//if (!endsWith(basePath, File.separator)) {
//    basePath = basePath + File.separator;
//}

print("Base Path: " + basePath);
print("XML Name: " + xmlName + ".xml");

// Run BigStitcher Definition
//run("BigStitcher", "select=define " + 
run("Define Multi-View Dataset",
    "define_dataset=[Automatic Loader (Bioformats based)] " + 
    "project_filename=" + xmlName + ".xml " + 
    "path=" + basePath  +" " +  
    "exclude=10 " + 
    "bioformats_channels_are?=Channels " + 
    "pattern_0=Tiles " + 
    "move_tiles_to_grid_(per_angle)?=[Do not move Tiles to Grid (use Metadata if available)] " + 
    "how_to_store_input_images=[Load raw data directly (no resaving)] " + 
    "load_raw_data_virtually " +    
    "metadata_save_path=" + File.getParent(basePath) + " " + 
    "image_data_save_path="+ File.getParent(basePath) + " " +
    "check_stack_sizes");

// Explicitly save the XML to the dataset folder
//run("Save XML");

print("Dataset definition complete.");

// Exit Fiji headless mode
eval("script", "System.exit(0);");