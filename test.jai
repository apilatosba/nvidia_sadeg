#import "Compiler";
#import "Basic";

#run {
   set_build_options_dc(.{ do_output = false });

   vertices := float.[
      -1, 0, 0,
      1, 0, 0,
      0, 1, 0
   ];

   print("%\n", size_of(type_of(vertices)));
}
