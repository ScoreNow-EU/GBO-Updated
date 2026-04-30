(
    function() {
        let vm = Vue.createApp({
            el: document.querySelector('#team-main'),
            data() {
                return {
                    team: [],
                    trainers: [],
                    staff: [],
                    errorstate: false,
                }
            },
            methods: {

                getPosition: function(pos) {
                    if(pos === 'LA' || pos === 'RA') {
                        return "outside-player"
                    } else if(pos === 'RR' || pos === 'RL' || pos === 'RM') {
                        return "backline-player"
                    } else if(pos === 'TW') {
                        return "goal-player"
                    } else if(pos === 'KM') {
                        return "circle-player"
                    } else {
                        return ""
                    }
                },
                getSquadInfo: async function() {
                    let api = initAxios();
                    const resp = await api.get('/wp-json/handball/squadInfo')
                        .catch(function(er) {
                            this.errorstate = true
                            console.log(er)
                        })

                    this.team = resp.data.players.map((x) => {
                        return {
                            name: x.firstname + " " + x.name,
                            position: this.getPosition(x.pos),
                            number: x.number,
                            link: x.link,
                            image: x.image,
                            sponsorLink: x.sponsorLink
                        }
                    })
                    this.trainers = resp.data.trainers.map((x) => {
                        return {
                            name: x.firstname + " " + x.name,
                            image: x.image,
                            sponsorLink: x.sponsorLink,
                            pos: x.pos === 'Chef Trainer' ? 'Cheftrainer' : x.pos
                        }
                    })
                    this.staff = resp.data.staff.map((x) => {
                        return {
                            name: x.firstname + " " + x.name,
                            image: x.image,
                            sponsorLink: x.sponsorLink,
                            pos: x.pos
                        }
                    })
					
					 this.mannschaftsarzt = resp.data.mannschaftsarzt.map((x) => {
                        return {
                            name: x.firstname + " " + x.name,
                            image: x.image,
                            sponsorLink: x.sponsorLink,
                            pos: x.pos
                        }
                    })
					
                    this.physiotherapeut = resp.data.physiotherapeut.map((x) => {
                        return {
                            name: x.firstname + " " + x.name,
                            image: x.image,
                            sponsorLink: x.sponsorLink,
                            pos: x.pos
                        }
                    })


                },


            },

            created: function() {
                this.getSquadInfo();
            },

            template: `
              <div  v-if="!errorstate">
                <div v-show="team.length === 0" style="color: white !important">loading..</div>

                <div class="lsm-vfl-vue-player-card-loop player-card-spacing" id="team-loop" >
                  <a v-for="player in team" :href="player.link" class="lsm-vfl-vue-player-card"
                     :class="player.position">
                    <div class="lsm-vfl-vue-player-card-number-space">
                      {{ player.number }}
                    </div>
                    <img class="lsm-vfl-vue-player-card-image-space" :src="player.image" :alt="player.name + ' Bild'"/>
                    <img class="lsm-vfl-vue-player-card-partner-space" v-if="player.sponsorLink"
                         :src="player?.sponsorLink" alt=""/>
                    <div class="lsm-vfl-vue-player-card-name-space">
                      {{ player.name }}
                    </div>
                  </a>
                </div>
                <div class="lsm-vfl-vue-player-card-loop player-card-spacing" id="trainer-loop" >
                  <div v-for="trainer in trainers" class="lsm-vfl-vue-player-card vfl-trainer-players">
                    <img class="lsm-vfl-vue-player-card-image-space" :src="trainer.image"
                         :alt="trainer.name + ' Bild'"/>
                    <img class="lsm-vfl-vue-player-card-partner-space" v-if="trainer.sponsorLink"
                         :src="trainer?.sponsorLink" alt=""/>
                    <div class="lsm-vfl-vue-player-card-name-space">
                      {{ trainer.name }}
                      <div class="lsm-vfl-trainer-pos">{{ trainer.pos }}</div>
                    </div>
                  </div>
                </div>
                <div class="lsm-vfl-vue-player-card-loop player-card-spacing" id="staff-loop">
                  <div v-for="staffPerson in staff" class="lsm-vfl-vue-player-card staff-player">
                    <img class="lsm-vfl-vue-player-card-image-space" :src="staffPerson.image"
                         :alt="staffPerson.name + ' Bild'"/>
                    <img class="lsm-vfl-vue-player-card-partner-space" v-if="staffPerson.sponsorLink"
                         :src="staffPerson?.sponsorLink" alt=""/>
                    <div class="lsm-vfl-vue-player-card-name-space">
                      {{ staffPerson.name }}
                      <div class="lsm-vfl-trainer-pos">{{ staffPerson.pos }}</div>
                    </div>
                  </div>
                </div>
				
                <div class="lsm-vfl-vue-player-card-loop player-card-spacing" id="mannschaftsarzt-loop">
                 <div v-for="mannschaftsarztPerson in mannschaftsarzt" class="lsm-vfl-vue-player-card staff-player">
                    <img class="lsm-vfl-vue-player-card-image-space" :src="mannschaftsarztPerson.image"
                         :alt="mannschaftsarztPerson.name + ' Bild'"/>
                    <img class="lsm-vfl-vue-player-card-partner-space" v-if="mannschaftsarztPerson.sponsorLink"
                         :src="mannschaftsarztPerson?.sponsorLink" alt=""/>
                    <div class="lsm-vfl-vue-player-card-name-space">
                      {{ mannschaftsarztPerson.name }}
                      <div class="lsm-vfl-trainer-pos">{{ mannschaftsarztPerson.pos }}</div>
                    </div>
                  </div>
                </div>
                <div class="lsm-vfl-vue-player-card-loop player-card-spacing" id="physiotherapeut-loop">
                  <div v-for="physiotherapeutPerson in physiotherapeut" class="lsm-vfl-vue-player-card staff-player">
                    <img class="lsm-vfl-vue-player-card-image-space" :src="physiotherapeutPerson.image"
                         :alt="physiotherapeutPerson.name + ' Bild'"/>
                    <img class="lsm-vfl-vue-player-card-partner-space" v-if="physiotherapeutPerson.sponsorLink"
                         :src="physiotherapeutPerson?.sponsorLink" alt=""/>
                    <div class="lsm-vfl-vue-player-card-name-space">
                      {{ physiotherapeutPerson.name }}
                      <div class="lsm-vfl-trainer-pos">{{ physiotherapeutPerson.pos }}</div>
                    </div>
                  </div>
                </div>
              </div>
              <div class="noContent" v-else>
                Es tut uns leid, der Inhalt konnte nicht geladen werden...
              </div>
            `,
        });

        vm.mount("#team-main");

    }
)();
