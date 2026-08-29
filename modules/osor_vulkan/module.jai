


#load "vulkan_header.jai";
// Header with all the Vulkan types, constants, commands, etc.
// with hopefully some useful documentation and links to help 
// understand the API.


#load "vulkan_loader.jai";
// File that handles loading the pointers to Vulkan's procedures.

#load "../Vulkan_Memory_Allocator/bindings.jai";
// vma. when they are seperate modules jai complains that same type is defined in two different places. so i put them into
// a single module like this and i only import this i dont import the Vulkan_Memory_Allocator seperately
