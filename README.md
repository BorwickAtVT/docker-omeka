Full credit to https://github.com/docker-library/wordpress for this
code. I just modified it a bit to make an Omeka version.

Commands
---

    make

    docker run --name omeka-mysql \
      -e MYSQL_ROOT_PASSWORD=mysecretpassword \
      -d mysql

    docker run --name omeka-app \
      --link omeka-mysql:mysql \
      -p 8080:80 \
	  -d omeka

Or for review:

    docker run --name omeka-app \
      -e "APPLICATION_ENV=development" \
      --link omeka-mysql:mysql \
      -p 8080:80 \
	  -d omeka

To reset the app:

    docker stop omeka-app && docker rm omeka-app

