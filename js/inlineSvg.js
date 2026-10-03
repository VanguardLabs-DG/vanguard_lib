export default {
    props: {
        src: {
            type: String,
            required: true
        },
        fill: {
            type: String,
            default: 'currentColor'
        }
    },
    data() {
        return {
            svg: ''
        }
    },
    watch: {
        async src(newSrc, oldSrc) {
            if (newSrc !== oldSrc) {
                this.fetchSVG(newSrc);
            }
        }
    },
    methods: {
        sanitizeSVG(svgText) {
            try {
                const parser = new DOMParser();
                const doc = parser.parseFromString(svgText, 'image/svg+xml');
                if (doc.querySelector('parsererror')) {
                    return '';
                }

                const root = doc.documentElement;
                if (!root || root.tagName.toLowerCase() !== 'svg') {
                    return '';
                }

                const ALLOWED_TAGS = new Set([
                    'svg', 'g', 'path', 'circle', 'rect', 'line', 'polyline', 'polygon',
                    'defs', 'clippath', 'mask', 'lineargradient', 'radialgradient', 'stop',
                    'text', 'tspan'
                ]);

                const ALLOWED_ATTRS = new Set([
                    'viewbox', 'fill', 'fill-rule', 'fill-opacity', 'stroke', 'stroke-width',
                    'stroke-linecap', 'stroke-linejoin', 'stroke-miterlimit', 'stroke-dasharray',
                    'stroke-dashoffset', 'stroke-opacity', 'd', 'cx', 'cy', 'r', 'rx', 'ry',
                    'x', 'y', 'x1', 'y1', 'x2', 'y2', 'points', 'width', 'height', 'xmlns',
                    'transform', 'class', 'id', 'gradientunits', 'gradienttransform',
                    'offset', 'stop-color', 'stop-opacity', 'clip-path', 'mask', 'opacity'
                ]);

                const elements = Array.from(doc.querySelectorAll('*'));
                for (const el of elements) {
                    const tagName = el.tagName.toLowerCase();
                    if (!ALLOWED_TAGS.has(tagName)) {
                        el.remove();
                        continue;
                    }

                    for (const attr of Array.from(el.attributes)) {
                        const attrName = attr.name.toLowerCase();
                        const attrVal = attr.value.trim().toLowerCase();

                        if (!ALLOWED_ATTRS.has(attrName) ||
                            attrName.startsWith('on') ||
                            attrName === 'style' ||
                            attrVal.includes('javascript:') ||
                            attrVal.includes('vbscript:') ||
                            attrVal.includes('data:')) {
                            el.removeAttribute(attr.name);
                        }
                    }
                }

                return root ? root.outerHTML : '';
            } catch (e) {
                return '';
            }
        },
        async fetchSVG(src) {
            try {
                const res = await fetch(src);
                if (res.ok) {
                    const html = await res.text();
                    this.svg = this.sanitizeSVG(html);
                } else {
                    console.error('SVG Loaded Error:', res.statusText);
                }
            } catch (error) {
                console.error('Fetch Error:', error);
            }
        }
    },
    mounted() {
        this.fetchSVG(this.src);
    },
    template: `
        <div v-html="svg" :style="{fill: fill}" />
    `
}

