FROM php:5.6-apache

# TODO I don't know why /var/lib/apt/lists is getting purged.
RUN apt-get update &&  apt-get install -y rsync \
    && apt-get install -y unzip \
    && rm -r /var/lib/apt/lists/*

RUN a2enmod rewrite

# install the PHP extensions we need
RUN apt-get update && apt-get install -y imagemagick \
    && apt-get install -y libpng12-dev libjpeg-dev && rm -rf /var/lib/apt/lists/* \
        && docker-php-ext-install exif \
  	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
 	&& docker-php-ext-install gd

RUN docker-php-ext-install mysqli

VOLUME /var/www/html

ENV OMEKA_VERSION 2.2.2
ENV OMEKA_SHA1 759c0892c143e3cdef494aeb8058d1b1be1ffe08

RUN curl -o omeka.zip -SL https://omeka.org/files/omeka-${OMEKA_VERSION}.zip \
	&& echo "$OMEKA_SHA1 *omeka.zip" | sha1sum -c - \
	&& unzip -d /usr/src/ omeka.zip \
	&& mv /usr/src/omeka-${OMEKA_VERSION} /usr/src/omeka \
	&& rm omeka.zip

COPY docker-entrypoint.sh /entrypoint.sh

# grr, ENTRYPOINT resets CMD now
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
