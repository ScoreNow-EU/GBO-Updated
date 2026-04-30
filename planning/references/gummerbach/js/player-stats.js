(
    function() {
        let vm = Vue.createApp({
            el: document.querySelector('#player-stats'),
            data() {
                return {
                    single_player_data: [],
                }
            },
            methods: {},

            mounted: function() {
               const data = localStorage.getItem("single_player_data")
			   this.single_player_data = JSON.parse(data)
            },
            template: `
			<div class="player-stats">
      <div>
        <div class="text-blue">{{single_player_data.Nation}}</div>
        <div class="text-dark">Nation</div>
      </div>
      <div>
        <div class="text-blue">{{single_player_data.birthday}}</div>
        <div class="text-dark">Geburtstag</div>
      </div>
      <div>
        <div class="text-blue">{{single_player_data.size}}</div>
        <div class="text-dark">Größe</div>
      </div>
      <div>
        <div class="text-blue">{{single_player_data.since}}</div>
        <div class="text-dark">Im Verein seit</div>
      </div>
    </div>`,
        });

        vm.mount("#player-stats");

    }
)();
