using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Outlines : MonoBehaviour
{
    public Material postProcessingMaterial;

    void Start() 
   {
      if (null == postProcessingMaterial || null == postProcessingMaterial.shader || 
         !postProcessingMaterial.shader.isSupported)
      {
         enabled = false;
         return;
      }	
   }

    public void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, postProcessingMaterial);
    }
}
