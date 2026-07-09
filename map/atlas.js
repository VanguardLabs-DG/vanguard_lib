const center_x = 117.3;
const center_y = 172.8;
const scale_x = 0.02072;
const scale_y = 0.0205;

const CUSTOM_CRS = L.extend({}, L.CRS.Simple, {
    projection: L.Projection.LonLat,
    scale: function (zoom) {
        return Math.pow(2, zoom);
    },
    zoom: function (sc) {
        return Math.log(sc) / 0.6931471805599453;
    },
    distance: function (pos1, pos2) {
        var x_difference = pos2.lng - pos1.lng;
        var y_difference = pos2.lat - pos1.lat;
        return Math.sqrt(x_difference * x_difference + y_difference * y_difference);
    },
    transformation: new L.Transformation(scale_x, center_x, -scale_y, center_y),
    infinite: true
});

const boundsTopLeft = CUSTOM_CRS.transformation.untransform(L.point([0, 0]));
const boundsBottomRight = CUSTOM_CRS.transformation.untransform(L.point([250, 250]));

const maxBounds = [
    [boundsTopLeft.y, boundsTopLeft.x],
    [boundsBottomRight.y, boundsBottomRight.x]
];

const SateliteStyle = L.tileLayer('nui://vanguard_lib/styleAtlas/{z}/{x}/{y}.jpg', {
    minZoom: 0,
    maxZoom: 5,
    noWrap: true,
    continuousWorld: false,
    id: 'styleAtlas map',
});

export { CUSTOM_CRS, maxBounds, SateliteStyle };
