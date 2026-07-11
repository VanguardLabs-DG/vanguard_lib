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
        async fetchSVG(src) {
            try {
                const res = await fetch(src);
                if (res.ok) {
                    const html = await res.text();
                    this.svg = html;
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
