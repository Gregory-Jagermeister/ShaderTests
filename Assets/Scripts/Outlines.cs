using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Outlines : MonoBehaviour
{
    public Material postProcessingMaterial;

    public void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, postProcessingMaterial);
    }
}
