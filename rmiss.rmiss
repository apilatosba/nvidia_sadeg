#version 460
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_descriptor_heap : enable
#extension GL_EXT_buffer_reference : enable
#extension GL_EXT_nonuniform_qualifier : enable

// Use the same payload location as the ray generation shader
layout(location = 0) rayPayloadInEXT vec3 hitColor;

void main() {
   // The ray missed everything. Make the background dark blue.
   hitColor = vec3(0.1, 0.2, 0.3);
}
