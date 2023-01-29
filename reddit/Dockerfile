FROM ruby:2.3
# Update the system and install build dependencies
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential=12.3 \
    # Delete the apt-get lists after installing something рекомендация hadolint
    && apt-get clean \ 
    && rm -rf /var/lib/apt/lists/*

# Set the environment variable for the app home directory
ENV APP_HOME /app

# Create the app home directory
RUN mkdir $APP_HOME
# Set the working directory to the app home directory
WORKDIR $APP_HOME
# Copy the Gemfile and Gemfile.lock to the app home directory
COPY Gemfile* $APP_HOME/
# Install the gems from the Gemfile
RUN bundle install
# Copy the rest of the app files to the app home directory
COPY . $APP_HOME

# Set the environment variable for the database URL
ENV DATABASE_URL mongo

# Start the app using the puma command
CMD ["puma"]
