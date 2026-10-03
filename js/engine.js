import {
    CfxTexture,
    LinearFilter,
    Mesh,
    NearestFilter,
    OrthographicCamera,
    PlaneBufferGeometry,
    RGBAFormat,
    Scene,
    ShaderMaterial,
    UnsignedByteType,
    WebGLRenderTarget,
    WebGLRenderer,
} from './Three.js';

import { postNUI } from './nui.js';

let _cameraChange = false;
export function setCameraChange(val) { _cameraChange = val; }
export function getCameraChange() { return _cameraChange; }





export const renderers = {
    MainRenderInstant: null,
    MainRenderCall: null,
};

function dataURItoBlob(dataURI) {
    const byteString = atob(dataURI.split(',')[1]);
    const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);
    for (let i = 0; i < byteString.length; i++) {
        ia[i] = byteString.charCodeAt(i);
    }
    return new Blob([ab], { type: mimeString });
}

export class GameRenderer {
    constructor(options = {}) {
        this.frameLimit = options.frameLimit || 1000 / 20;
        this.width = window.innerWidth;
        this.height = window.innerHeight;

        this.cameraRTT = new OrthographicCamera(this.width / -2, this.width / 2, this.height / 2, this.height / -2, -10000, 10000);
        this.cameraRTT.position.z = 0;
        this.sceneRTT = new Scene();

        this.rtTexture = new WebGLRenderTarget(this.width, this.height, {
            minFilter: LinearFilter,
            magFilter: NearestFilter,
            format: RGBAFormat,
            type: UnsignedByteType,
        });

        this.gameTexture = new CfxTexture();
        this.gameTexture.needsUpdate = true;

        this.material = new ShaderMaterial({
            uniforms: { tDiffuse: { value: this.gameTexture } },
            vertexShader: [
                'varying vec2 vUv;',
                'void main() {',
                '  vUv = vec2(uv.x, 1.0 - uv.y);',
                '  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);',
                '}',
            ].join('\n'),
            fragmentShader: [
                'varying vec2 vUv;',
                'uniform sampler2D tDiffuse;',
                'void main() {',
                '  gl_FragColor = texture2D(tDiffuse, vUv);',
                '}',
            ].join('\n'),
        });

        const plane = new PlaneBufferGeometry(this.width, this.height);
        const quad = new Mesh(plane, this.material);
        quad.position.z = -100;
        this.sceneRTT.add(quad);

        this.renderer = new WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
        this.renderer.setSize(this.width, this.height);
        this.renderer.autoClear = false;

        const appendArea = document.createElement('div');
        appendArea.id = 'three-game-render';
        document.body.append(appendArea);
        appendArea.appendChild(this.renderer.domElement);
        appendArea.style.display = 'none';

        this.canvas = document.createElement('canvas');
        this.canvas.width = this.width;
        this.canvas.height = this.height;
        this.canvas.style.display = 'none';
        document.body.append(this.canvas);
        this.ctx = this.canvas.getContext('2d', { willReadFrequently: true });

        this.tempCanvas = null;

        this.pixelBuffer = new Uint8Array(this.width * this.height * 4);
        this.imageData = new ImageData(new Uint8ClampedArray(this.pixelBuffer.buffer), this.width, this.height);

        this.isRunning = false;
        this.isLooping = false;
        this.lastRender = 0;

        window.addEventListener('resize', () => this.resize());
        this.animate = this.animate.bind(this);
    }

    resize() {
        this.width = window.innerWidth;
        this.height = window.innerHeight;

        const cameraRTT = new OrthographicCamera(this.width / -2, this.width / 2, this.height / 2, this.height / -2, -10000, 10000);
        cameraRTT.position.z = 100;

        let adjustedWidth = this.width;
        let screenLeft = 0;

        if (this.customCamRatio) {
            adjustedWidth = Math.floor(this.height * this.customCamRatio);
            screenLeft = this.screenLeft;
        }

        cameraRTT.setViewOffset(this.width, this.height, screenLeft, 0, adjustedWidth, this.height);
        this.cameraRTT = cameraRTT;

        const plane = new PlaneBufferGeometry(this.width, this.height);
        const quad = new Mesh(plane, this.material);
        quad.position.z = -100;

        this.sceneRTT = new Scene();
        this.sceneRTT.add(quad);
        this.rtTexture.setSize(this.width, this.height);
        this.renderer.setSize(this.width, this.height);

        this.pixelBuffer = new Uint8Array(this.width * this.height * 4);
        this.imageData = new ImageData(new Uint8ClampedArray(this.pixelBuffer.buffer), this.width, this.height);

        this.canvas.width = this.width;
        this.canvas.height = this.height;
    }

    animate() {
        if (!this.isRunning) {
            this.isLooping = false;
            return;
        }
        requestAnimationFrame(this.animate);

        const now = performance.now();
        if (now - this.lastRender < this.frameLimit) return;
        this.lastRender = now;

        this.renderer.render(this.sceneRTT, this.cameraRTT);
    }

    createTempCanvas() {
        this.tempCanvas = document.createElement('canvas');
        this.tempCanvas.style.display = 'inline';
        this.tempCanvas.width = this.width;
        this.tempCanvas.height = this.height;
    }

    renderToTarget(element, ratio, left) {
        if (ratio) {
            this.customCamRatio = ratio;
            this.screenLeft = left;
            let width = Math.floor(this.height * this.customCamRatio);
            this.cameraRTT.setViewOffset(this.width, this.height, this.screenLeft, 0, width, this.height);
        }
        element.style.display = 'none';
        this.renderer.domElement.className = element.className;
        this.renderer.domElement.style.cssText = element.style.cssText;
        this.renderer.domElement.style.display = 'inline';
        if (element.parentNode && this.renderer.domElement.parentNode !== element.parentNode) {
            element.parentNode.insertBefore(this.renderer.domElement, element);
        }
        this.canvas = element;
        this.isRunning = true;
        if (!this.isLooping) {
            this.isLooping = true;
            this.lastRender = performance.now();
            requestAnimationFrame(this.animate);
        }
    }

    requestScreenshot = async (url, field, UploadMethod) => {
        return new Promise(async (resolve) => {
            url = url || '';
            field = field || 'image';
            this.isRunning = false;
            await new Promise((resolve) => setTimeout(resolve, 10));
            const imageURL = this.renderer.domElement.toDataURL('image/png', 1.0);
            const formData = new FormData();
            formData.append(field, dataURItoBlob(imageURL), 'screenshot.png');
            let uploadUrl = url || '';
            let headers = {};
            if (UploadMethod === 'fivemanage') {
                headers['Authorization'] = uploadUrl;
                uploadUrl = 'https://api.fivemanage.com/api/image';
            }

            if (!uploadUrl || typeof uploadUrl !== 'string' || (!uploadUrl.startsWith('https://') && !uploadUrl.startsWith('http://'))) {
                console.error('[Vanguard Engine] URL de upload de screenshot inválida ou insegura.');
                postNUI('ERROR_PHOTO_UPLOAD_INSTANT');
                resolve(false);
                return;
            }

            fetch(uploadUrl, {
                method: 'POST',
                headers: headers,
                body: formData,
            })
                .then((response) => response.json())
                .then((data) => {
                    if ((data.attachments && data.attachments.length > 0) || data.url) {
                        resolve(data.attachments && data.attachments.length > 0 ? data.attachments[0].url : data.url);
                    } else {
                        postNUI('ERROR_PHOTO_UPLOAD_INSTANT');
                        resolve(false);
                    }
                    this.isRunning = true;
                    if (!this.isLooping) {
                        this.isLooping = true;
                        this.lastRender = performance.now();
                        requestAnimationFrame(this.animate);
                    }
                })
                .catch((error) => {
                    postNUI('ERROR_PHOTO_UPLOAD_INSTANT');
                    resolve(false);
                });
        });
    };

    stop() {
        this.isRunning = false;
        this.isLooping = false;
        if (this.renderer && this.renderer.domElement) {
            this.renderer.domElement.style.display = 'none';
        }
    }
}

export function showCamera() {
    if (!renderers.MainRenderInstant) {
        renderers.MainRenderInstant = new GameRenderer();
    } else {
        if (renderers.MainRenderInstant.renderer && renderers.MainRenderInstant.renderer.domElement) {
            renderers.MainRenderInstant.renderer.domElement.style.display = 'inline';
        }
    }
    prepareCamera();
}
window.showCamera = showCamera;
window._vp_renderers = renderers;
window._vp_setCameraChange = setCameraChange;
window._vp_getCameraChange = getCameraChange;

function prepareCamera() {
    let screen = document.getElementById('tempCanvasInstantCamera');
    if (!screen) {
        console.error('tempCanvas element not found!');
        return;
    }
    window.innerWidth = 500;
    window.innerHeight = 700;
    if (_cameraChange) {
        renderers.MainRenderInstant.screenLeft = 95.0;
    } else {
        renderers.MainRenderInstant.screenLeft = 200.0;
    }
    renderers.MainRenderInstant.renderToTarget(screen, 0.25, renderers.MainRenderInstant.screenLeft);
    renderers.MainRenderInstant.resize(false);
}

export function TakePhotoInstant(webhookData, UploadMethod) {
    let webhook = webhookData || null;
    let uploadmethod = UploadMethod || null;
    setTimeout(() => {
        renderers.MainRenderInstant.requestScreenshot(webhook, 'image', uploadmethod).then((result) => {
            if (result) {
                postNUI('TakePhotoInstant', result);
            } else {
                postNUI('ERROR_PHOTO_UPLOAD_INSTANT');
            }
        });
    }, 10);
}
window.TakePhotoInstant = TakePhotoInstant;
