

function initAxios(){
	return axios.create({
  		baseURL: 'https://www.vfl-gummersbach.de',
		headers: {
    		'Content-Type': 'application/json',
    		'Access-Control-Allow-Origin': '*'
		}
	})
}