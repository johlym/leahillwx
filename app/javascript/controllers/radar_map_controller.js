import { Controller } from "@hotwired/stimulus"
import { Map, TileLayer } from "leaflet"

export default class extends Controller {
  static values = {
    lat: Number,
    lon: Number
  }

  connect() {
    const map = new Map(this.element, {
      center: [this.latValue, this.lonValue],
      zoom: 8
    })

    new TileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(map)
  }
}
