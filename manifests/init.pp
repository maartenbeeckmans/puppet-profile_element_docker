#
#
#
class profile_element_docker (
  String        $image,
  String        $listen_address,
  Integer       $listen_port,
  String        $config_file_path,
  String        $homeserver_url,
  String        $homeserver_name,
  String        $jitsi_url,
  String        $sd_service_name,
  Array[String] $sd_service_tags,
  Boolean       $manage_sd_service            = lookup('manage_sd_service', Boolean, first, true),
) {
  $_config = {
    'default_server_config'           => {
      'm.homeserver'     => {
        'base_url'    => $homeserver_url,
        'server_name' => $homeserver_name,
      },
      'm.identityserver' => {
        'base_url'    => $homeserver_url,
      }
    },
    'disable_custom_urls'             => false,
    'disable_guests'                  => false,
    'disable_login_language_selector' => false,
    'disable_3pid_login'              => false,
    'brand'                           => 'Element',
    'defaultCountryCode'              => 'BE',
    'default_federate'                => true,
    'default_theme'                   => 'light',
    'roomDirectory'                   => {
      'servers' => [ 'matrix.org', $homeserver_url ],
    },
    'settingDefaults'                 => {
      'breadcrumbs' => true,
    },
    'jitsi'                           => {
      'preferredDomain' => $jitsi_url,
    },
  }

  file { $config_file_path:
    ensure  => 'present',
    content => hash2json($_config),
  }

  docker::run { 'element':
    image        => $image,
    ports        => ["${listen_address}:${listen_port}:80/tcp"],
    volumes      => ["${config_file_path}:/app/config.json"],
  }

  firewall { "0${listen_port} allow element":
    dport  => $listen_port,
    action => $accept,
  }

  if $manage_sd_service {
    consul::service { $sd_service_name:
      checks => [
        {
          http     => "http://${listen_address}:${listen_port}",
          interval => '10s',
        }
      ],
      port   => $listen_port,
      tags   => $sd_service_tags,
    }
  }

  File[$config_file_path] ~> Docker::Run['element']
}
