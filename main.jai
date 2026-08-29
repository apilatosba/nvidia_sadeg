#import "Basic";
#import "VulkanJai";
#import "ApilaDispatch";
#import "File";
#import "stb_image";
#import "osor_vulkan";
#import "glfw";
#import "System";
#import "String";
#import "Ecs";

//
// prolly the algorithm i would implement this summer Clueless.
//    paper: https://research.nvidia.com/labs/rtr/publication/lin2026restirptenhanced/
// it is enhanced version of restirpt. nvidia here has an implementation of restirpt:
//    docs:          https://github.com/NVIDIA-RTX/RTXDI/blob/main/Doc/RestirPT.md
//    the commit:    https://github.com/NVIDIA-RTX/RTXDI/commit/274141af082050c9d0ad6e01a2e591d0d66b7955
//
// you need to first implement the restirpt then you need to convert it to enhanced version from what you understand from the paper above.
// this guy (DQLin), also the coaouther of the paper above, has his own implementation of restirpt here: https://github.com/DQLin/ReSTIR_PT
// maybe thats also useful. but now unfortunately i cant work on this yet because i have exams. fuck uni for that reason.
//
// this repo implements restirgi not restirpt: https://github.com/EmbarkStudios/kajiya/blob/main/docs/gi-overview.md
// but i think it still can be may be useful since it is a working code example. you never know until you know you know Cluless.
//
//          - apila, 08/07/26
//

main :: () {
   SetCurrentWorkingDirectoryToPathOfRunningExecutable();
   InitializeThreads();
   window := InitializeVulkanAndWindow(1024, 1024);

   #if true {

   rgenSpv, ok := read_entire_file("rgen.spv");
   assert(ok);
   rchitSpv:, ok = read_entire_file("rchit.spv");
   assert(ok);
   rmissSpv:, ok = read_entire_file("rmiss.spv");
   assert(ok);

   rgenDataCpuUntyped, rgenDataGpu := GpuMalloc(size_of(s32) * 2, 16);
   assert(rgenDataCpuUntyped != null);
   rgenDataCpu := rgenDataCpuUntyped.(*s32);
   defer GpuFree(rgenDataGpu);

   IMAGE_WIDTH    :: 640;
   IMAGE_HEIGHT   :: 480;
   imageSize := IMAGE_HEIGHT * IMAGE_WIDTH * 4;

   outputImageDescription: ImageDescription = .{
      size = .[IMAGE_WIDTH, IMAGE_HEIGHT, 1],
      format = VK_FORMAT_R8G8B8A8_UNORM,
      arrayLayers = 1,
      mipLevels = 1,
      sampleCount = 1,
      usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
   };

   size, alignment := ImageSizeAndAlignment(outputImageDescription);
   _, outputImageGpu := GpuMalloc(size, alignment, .Gpu);
   outputImage := CreateImage(outputImageGpu, outputImageDescription);

   resourceHeapCursor := 0;
   outputImageOffset := resourceHeapCursor;
   WriteImageDescriptors(outputImageOffset, .[outputImage], .Storage);
   resourceHeapCursor += GetSizeOfDescriptors(.[outputImage]);

   vertexBufferCpu, vertexBufferGpu := GpuMalloc(3 * size_of(float) * 3, 0, IS_GEOMETRY = true);

   vertices := float.[
      -1, 0, 0,
      1, 0, 0,
      0, 1, 0
   ];

   memcpy(vertexBufferCpu, vertices.data, size_of(type_of(vertices)));

   indices := u16.[
      0, 1, 2
   ];

   indexBufferCpu, indexBufferGpu := GpuMalloc(3 * size_of(u16), 0, IS_GEOMETRY = true);

   memcpy(indexBufferCpu, indices.data, size_of(type_of(indices)));

   geometry: TrianglesInfo = .{
      vertexFormat = VK_FORMAT_R32G32B32_SFLOAT,
      vertexData = vertexBufferGpu,
      vertexCount = 3,
      vertexStride = 3 * size_of(float),
      indexType = .VK_INDEX_TYPE_UINT16,
      indexData = indexBufferGpu,
      primitiveCount = 1,
      localToRootMatrix = IDENTITY_TRANSFORM_MATRIX,
   };

   blas := BuildBLAS(.[geometry]);

   blasModelMatrix: VkTransformMatrixKHR = .{
      matrix = .[
         .[1, 0, 0, 0],
         .[0, 1, 0, 0],
         .[0, 0, 1, 0],
      ]
   };

   instance: InstanceInfo = .{
      blasReference = blas,
      modelMatrix = blasModelMatrix,
      customIndex = 0,
      mask = 0xFF,
      sbtRecordOffset = 0,
      flags = 0,
   };

   tlas := BuildTLAS(.[instance]);

   resourceHeapCursor = Align(resourceHeapCursor, xx vk.descriptorHeapProperties.bufferDescriptorAlignment);
   tlasOffset := resourceHeapCursor;
   WriteAccelerationStructureDescriptors(tlasOffset, .[tlas]);
   resourceHeapCursor += GetSizeOfDescriptors(.[tlas]);

   // rgen.rgen declares the TLAS as layout(set = 0, binding = 0).  The
   // pipeline maps that declaration to this descriptor heap offset instead of
   // having the shader load an acceleration structure directly from ResourceHeapEXT.
   rtxPipeline := CreateRayTracingPipeline(.[xx rgenSpv], .[xx rmissSpv], .[.{ closestHit = xx rchitSpv }], 1/* , tlasOffset */);
   defer DestroyRayTracingPipeline(rtxPipeline);

   rgenDataCpu[0] = xx tlasOffset;
   rgenDataCpu[1] = xx outputImageOffset;

   // if i call TraceRays below then i only get two iterations (third iteration stalls).
   // three also equals to the number of frames in flight there are. so i think there is a synchronization issue.
   while (!glfwWindowShouldClose(window.window)) {
      AcquireSwapchainImage(window);
      glfwPollEvents();

      cmd := StartCommandRecording();
      ActivateDescriptorHeaps(cmd);


      BindRayTracingPipeline(cmd, rtxPipeline);
      TraceRays(cmd, rtxPipeline, 0, IMAGE_WIDTH, IMAGE_HEIGHT, 1, rgenDataGpu);

      BlitImage(cmd, outputImage, window.swapchainImages[window.swapchainImageIndex], 0, 0, VK_FILTER_NEAREST);

      SubmitAndPresent(cmd, window);
   print("%\n", window.cpuFrameTimeline);

      reset_temporary_storage();
   }

   WaitDevice();

   }

   #if false {

   ok: bool;
   meshSpv:, ok = read_entire_file("MeshShader.spv");
   assert(ok);
   fragmentSpv:, ok = read_entire_file("FragmentShader.spv");
   assert(ok);

   pipeline := CreateMeshletPipeline(.{}, xx meshSpv, xx fragmentSpv);
   defer DestroyMeshletPipeline(pipeline);
   fragmentDataCpu, fragmentDataGpu := GpuMalloc(int, 2);
   defer GpuFree(fragmentDataGpu);

   meshDataCpu, meshDataGpu := GpuMalloc(float, 1);
   defer GpuFree(meshDataGpu);

   stbi_set_flip_vertically_on_load(xx true);

   imageWidth: s32;
   imageHeight: s32;
   channelCount: s32;
   imageData := stbi_load("Lenna.png", *imageWidth, *imageHeight, *channelCount, 4);
   defer stbi_image_free(imageData);

   imageSize := imageWidth * imageHeight * 4;
   stagingCpu, stagingGpu := GpuMalloc(imageSize, 0);
   defer GpuFree(stagingGpu);
   memcpy(stagingCpu, imageData, imageSize);

   lennaDescription: ImageDescription = .{
      size = .[xx imageWidth, xx imageHeight, 1],
      format = VK_FORMAT_R8G8B8A8_SRGB,
      arrayLayers = 1,
      mipLevels = 1,
      sampleCount = 1,
      usage = VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
   };
   size, alignment := ImageSizeAndAlignment(lennaDescription);
   _, lennaImageGpu := GpuMalloc(size, alignment, .Gpu);
   lennaImage := CreateImage(lennaImageGpu, lennaDescription);

   WriteImageDescriptors(5 * GetSizeOfDescriptors(.[lennaImage]), .[lennaImage], .Sampled);
   WriteSamplerDescriptors(0, .[.{}]);

   {
      uploadCmd := StartCommandRecording();
      defer Submit(uploadCmd);

      CopyToImage(uploadCmd, stagingGpu, lennaImage);
      GpuBarrier(uploadCmd, VK_PIPELINE_STAGE_2_TRANSFER_BIT, VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT);
   }

   while (!glfwWindowShouldClose(window.window)) {
      AcquireSwapchainImage(window);
      glfwPollEvents();

      cmd := StartCommandRecording();
      ActivateDescriptorHeaps(cmd);

      timeSinceStart: float = xx glfwGetTime();
      // fragmentDataCpu[0] = .{ (sin(10 * timeSinceStart) + 1) / 2, (sin(20 * timeSinceStart) + 1) / 2, (sin(30 * timeSinceStart) + 1) / 2, 1 };

      fragmentDataCpu[0] = 160;
      fragmentDataCpu[1] = 0;

      meshDataCpu[0] = timeSinceStart / 3;

      renderPassDescription: RenderPassDescription = .{
         colorTargets = .[
            .{
               image = *window.swapchainImages[window.swapchainImageIndex],
               hasClearValue = true,
               clearValue = .{
                  color = .{ 1, 0, 1, 1 }
               },
            },
         ],
         hasDepthTarget = false,
         hasStencilTarget = false,
      };

      {
         BeginRenderPass(cmd, renderPassDescription);
         defer EndRenderPass(cmd);

         BindMeshletPipeline(cmd, pipeline);
         DispatchMesh(cmd, 0, meshDataGpu, fragmentDataGpu, 1, 1, 1);
      }

      SubmitAndPresent(cmd, window);

      reset_temporary_storage();
   }

   WaitDevice();
   }
}

SetCurrentWorkingDirectoryToPathOfRunningExecutable :: () {
   folder := get_path_of_running_executable();
   folder = path_strip_filename(folder);
   ok := set_working_directory(folder);
   assert(ok);
}
