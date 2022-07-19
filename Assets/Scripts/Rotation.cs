using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Rotation : MonoBehaviour
{
    public GameObject target;
    public int speed = 100;

    // Update is called once per frame
    void Update()
    {

        transform.RotateAround(target.transform.position, Vector3.up, speed * Time.deltaTime);
    }
}
