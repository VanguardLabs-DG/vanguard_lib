import { postNUI } from './nui.js';
import { renderers, GameRenderer } from './engine.js';

let sender = false;
let serverId = null;
let watching = false;
let streaming = false;
let callId = null;
let localStream = null;
let peerConn = null;
let SenderpeerConn = null;

const RTCServers = {
    iceServers: [
        {
            urls: 'stun:stun.l.google.com:19302',
        },
        {
            urls: ['turn:eu-0.turn.peerjs.com:3478', 'turn:us-0.turn.peerjs.com:3478'],
            username: 'peerjs',
            credential: 'peerjsp',
        },
    ],
    iceTransportPolicy: 'relay',
    sdpSemantics: 'unified-plan',
};

function sendData(data) {
    data.callId = parseInt(callId);
    data.serverId = parseInt(serverId);
    postNUI('sendData', data);
}

async function handleSignallingData(data) {
    switch (data.type) {
        case 'offer':
            let sessionDesc = new RTCSessionDescription(data.offer);
            await peerConn.setRemoteDescription(sessionDesc);
            createAndSendAnswer();
            break;
        case 'candidate':
            let candidate = new RTCIceCandidate(data.candidate);
            peerConn.addIceCandidate(candidate);
    }
}

async function createAndSendAnswer() {
    let candidateAnswer = await peerConn.createAnswer();
    await peerConn.setLocalDescription(candidateAnswer);
    let answerObject = {
        sdp: candidateAnswer.sdp,
        type: candidateAnswer.type,
    };
    sendData({
        type: 'send_answer',
        answer: answerObject,
    });
}

export function joinCall() {
    if (!renderers.MainRenderCall) {
        renderers.MainRenderCall = new GameRenderer();
    }
    watching = true;
    callId = serverId;
    peerConn = new RTCPeerConnection(RTCServers);
    let canvas = document.getElementById('local-video');
    renderers.MainRenderCall.renderToTarget(canvas);
    let stream = canvas.captureStream();
    localStream = stream;
    document.getElementById('local-video').srcObject = localStream;
    let video = document.getElementById('remote-video');
    video.srcObject = new MediaStream();
    peerConn.onicecandidate = (e) => {
        if (e.candidate == null) return;
        // Previne vazamento de IP residencial dos jogadores via candidatos host/srflx
        if (e.candidate.candidate && (e.candidate.candidate.includes('typ host') || e.candidate.candidate.includes('typ srflx'))) {
            return;
        }
        let candidate = new RTCIceCandidate(e.candidate);
        peerConn.addIceCandidate(candidate);
        sendData({
            type: 'send_candidate',
            candidate: candidate,
        });
    };
    peerConn.ontrack = (event) => {
        event.streams[0].getTracks().forEach((track) => {
            video.srcObject.addTrack(track);
        });
    };
    localStream.getTracks().forEach(function (track) {
        peerConn.addTrack(track, localStream);
    });
    sendData({
        type: 'join_call',
    });
}

async function handleSignallingDataSender(data) {
    switch (data.type) {
        case 'answer':
            let answer = new RTCSessionDescription(data.answer);
            await SenderpeerConn.setRemoteDescription(answer);
            break;
        case 'candidate':
            let candidate = new RTCIceCandidate(data.candidate);
            SenderpeerConn.addIceCandidate(candidate);
    }
}

function sendcallId(result) {
    callId = result;
    sendData({
        type: 'store_user',
    });
}

export async function startCall(result) {
    streaming = true;
    sender = true;
    try {
        renderers.MainRenderCall = new GameRenderer();
        await sendcallId(result);
        let screen = document.getElementById('local-video');
        if (!screen) {
            console.error('tempCanvas element not found!');
            return;
        }
        if (localStream) {
            localStream.getTracks().forEach((track) => track.stop());
        }
        renderers.MainRenderCall.renderToTarget(screen);
        let stream = screen.captureStream();
        document.getElementById('local-video').srcObject = stream;
        localStream = stream;

        SenderpeerConn = new RTCPeerConnection(RTCServers);
        localStream.getTracks().forEach((track) => SenderpeerConn.addTrack(track, localStream));
        SenderpeerConn.ontrack = (event) => {
            document.getElementById('remote-video').srcObject = event.streams[0];
        };
        SenderpeerConn.onicecandidate = (event) => {
            if (event.candidate) {
                // Previne vazamento de IP residencial dos jogadores via candidatos host/srflx
                if (event.candidate.candidate && (event.candidate.candidate.includes('typ host') || event.candidate.candidate.includes('typ srflx'))) {
                    return;
                }
                const senderCandidate = new RTCIceCandidate(event.candidate);
                SenderpeerConn.addIceCandidate(senderCandidate).catch((e) => {});
                sendData({
                    type: 'store_candidate',
                    candidate: senderCandidate,
                });
            }
        };

        let candidateOffer = await SenderpeerConn.createOffer();
        await SenderpeerConn.setLocalDescription(candidateOffer);
        let offerObject = {
            sdp: candidateOffer.sdp,
            type: candidateOffer.type,
        };
        sendData({
            type: 'store_offer',
            offer: offerObject,
        });

        postNUI('startCallId', { id: callId });
    } catch (error) {
        console.error('Error during call setup:', error);
    }
}

export function stopCall() {
    if (streaming) {
        streaming = false;
        sender = false;
        serverId = null;
        callId = null;
        if (SenderpeerConn) {
            SenderpeerConn.close();
            SenderpeerConn = null;
        }
        if (renderers.MainRenderCall) {
            renderers.MainRenderCall.stop();
            renderers.MainRenderCall = null;
        }
    } else if (watching) {
        watching = false;
        sender = false;
        callId = null;
        if (peerConn) {
            peerConn.close();
            peerConn = null;
        }
        if (renderers.MainRenderCall) {
            renderers.MainRenderCall.stop();
            renderers.MainRenderCall = null;
        }
    }
}

function ListenerServerData(data) {
    sender ? handleSignallingDataSender(data) : handleSignallingData(data);
}

window.addEventListener('message', function (e) {
    const message = e.data;
    if (message.type === 'sendData') {
        ListenerServerData(message.data);
    } else if (message.type === 'answer' || message.type === 'open') {
        serverId = message.serverId;
    }
});
