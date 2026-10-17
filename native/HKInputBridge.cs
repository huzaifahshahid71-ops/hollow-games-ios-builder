using System;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
namespace HKPort {
 public static class KeyboardBridge {
  static readonly bool[] held=new bool[160]; static bool announced;
  static Key Map(int key) {switch(key){case 36:return Key.Enter;case 53:return Key.Escape;case 49:return Key.Space;case 48:return Key.Tab;case 34:return Key.I;case 46:return Key.M;case 123:return Key.LeftArrow;case 124:return Key.RightArrow;case 125:return Key.DownArrow;case 126:return Key.UpArrow;case 0:return Key.A;case 1:return Key.S;case 2:return Key.D;case 3:return Key.F;case 6:return Key.Z;case 7:return Key.X;case 8:return Key.C;case 9:return Key.V;default:return Key.None;}}
  public static void SetKey(int mac,int down) {
   Key key=Map(mac);if(key==Key.None)return;
   Keyboard keyboard=Keyboard.current;
   if(keyboard==null){Debug.Log("HK input: no current keyboard");return;}
   held[(int)key]=down!=0;int count=0;for(int i=1;i<held.Length;i++)if(held[i])count++;
   Key[] keys=new Key[count];int index=0;for(int i=1;i<held.Length;i++)if(held[i])keys[index++]=(Key)i;
   InputSystem.QueueStateEvent<KeyboardState>(keyboard,new KeyboardState(keys));
   if(!announced){announced=true;Debug.Log("HK input: queued state for "+keyboard.name+" id="+keyboard.deviceId);}
  }
 }
}
