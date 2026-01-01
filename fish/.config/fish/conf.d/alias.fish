alias l="ls -l"

alias dc='docker-compose'
alias py='python'
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'
alias helm='[ -f alto ] && bash alto || echo Error: alto not found'
alias win2utf='iconv -f WINDOWS-1251 -t UTF-8'
alias fnvim='nvim $(fzf)'

alias wp='docker-compose run --rm wpcli wp'

function dc_chown --description 'Chown all files in provided with $1 container name to www-data user'
  if [ -z $2 ]
					set 2 'www-data'
  end
	docker-compose exec -t $1 bash -c 'chown -R $2 *'
end
