import * as THREE from "https://unpkg.com/three@0.160.0/build/three.module.js";

import { GLTFLoader }
from "https://unpkg.com/three@0.160.0/examples/jsm/loaders/GLTFLoader.js";

import { VRMLoaderPlugin }
from "https://unpkg.com/@pixiv/three-vrm@2/lib/three-vrm.module.js";

const scene=new THREE.Scene();

const camera=new THREE.PerspectiveCamera(
35,
window.innerWidth/window.innerHeight,
0.1,
1000
);

camera.position.set(
0,
1.4,
2
);

const renderer=
new THREE.WebGLRenderer(
{
alpha:true
}
);

renderer.setSize(
window.innerWidth,
window.innerHeight
);

document.body.appendChild(
renderer.domElement
);

const light=
new THREE.DirectionalLight(
0xffffff,
1
);

light.position.set(
1,
1,
1
);

scene.add(light);

const loader=
new GLTFLoader();

loader.register(
(parser)=>
new VRMLoaderPlugin(parser)
);

loader.load(
"/assets/avatar/Lucky.vrm",

(vrm)=>{

scene.add(
vrm.userData.vrm.scene
);

},

undefined,

(error)=>{
console.log(error);
}
);

function animate(){

requestAnimationFrame(
animate
);

renderer.render(
scene,
camera
);

}

animate();