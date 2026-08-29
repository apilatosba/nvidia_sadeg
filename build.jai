#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Basic";
#import "ApilaSpirv";

// config
BUILD_FOLDER      :: "build";
OUTPUT_EXE_NAME   :: "main";

#run {
   assert(OS == .LINUX, "only linux supported, cause i dont have dlls for windows");

   set_build_options_dc(.{ do_output = false });
   set_working_directory(#filepath);

   rootOptions := get_build_options();

   w := compiler_create_workspace("Target Program (main)");
   make_directory_if_it_does_not_exist(BUILD_FOLDER);

   options := get_build_options(w);
   copy_commonly_propagated_fields(rootOptions, *options);
   options.output_executable_name = OUTPUT_EXE_NAME;
   options.output_path = BUILD_FOLDER;

   {
      importPath: [..] string;
      for options.import_path {
         array_add(*importPath, it);
      }

      array_add(*importPath, "../vulkan_jai/");

      options.import_path = importPath;
   }

   set_build_options(options, w);

   // compile
   {
      compiler_begin_intercept(w);
      defer compiler_end_intercept(w);

      add_build_file("main.jai", w);

      while true {
         message := compiler_wait_for_message();
         if message.kind == {
            case .COMPLETE; {
               mc := cast(*Message_Complete) message;
               if mc.error_code != .NONE {
                  compiler_set_workspace_status(.FAILED, w);
                  exit(69);
               }
               break;
            }
         }
      }
   }

   // w = compiler_create_workspace("Shader Program");
   // options = get_build_options(w);
   // copy_commonly_propagated_fields(rootOptions, *options);
   // options.output_type = .NO_OUTPUT;
   // set_build_options(options, w);

   // shaderOptions := GetBuildOptions(w);
   // shaderOptions.buildFolder = BUILD_FOLDER;
   // SetBuildOptions(shaderOptions, w);

   // // compile shaders
   // {
   //    compiler_begin_intercept(w);
   //    defer compiler_end_intercept(w);

   //    add_build_file("shaders.jai", w);

   //    while true {
   //       message := compiler_wait_for_message();
   //       ProcessMessage(message);

   //       if message.kind == {
   //          case .COMPLETE; {
   //             mc := cast(*Message_Complete) message;
   //             if mc.error_code != .NONE {
   //                compiler_set_workspace_status(.FAILED, w);
   //                exit(69);
   //             }
   //             break;
   //          }
   //       }
   //    }
   // }

   // copy sos
   copy_file("modules/Vulkan_Memory_Allocator/linux/libvma.so", tprint("%/libvma.so", BUILD_FOLDER));
   copy_file("modules/SpirvTools/linux/libSPIRV-Tools-shared.so", tprint("%/libSPIRV-Tools-shared.so", BUILD_FOLDER));

   copy_file("modules/glfw/linux/libglfw.so", tprint("%/libglfw.so", BUILD_FOLDER));
   copy_file("modules/glfw/linux/libglfw.so.3", tprint("%/libglfw.so.3", BUILD_FOLDER));
   copy_file("modules/glfw/linux/libglfw.so.3.5", tprint("%/libglfw.so.3.5", BUILD_FOLDER));

   // copy assets
   copy_file("Lenna.png", tprint("%/Lenna.png", BUILD_FOLDER));

   // copy spvs
   copy_file("rmiss.spv", tprint("%/rmiss.spv", BUILD_FOLDER));
   copy_file("rgen.spv", tprint("%/rgen.spv", BUILD_FOLDER));
   copy_file("rchit.spv", tprint("%/rchit.spv", BUILD_FOLDER));
}
