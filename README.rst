TaraCert
========

Provides a parameterized Let's Encrypt renewal loop, a self-signed
bootstrap for dev, and a SIGHUP-based reload mechanism for dependent
services.

Usage
-----

Add as a git submodule at ``./taracert`` in the consuming project:

.. code-block:: sh

   git submodule add git@github.com:cr3/taracert.git taracert

Include the shared compose fragment in the project's ``compose.yml``:

.. code-block:: yaml

   include:
     - path: ./taracert/compose.yml

   services:
     nginx:
       depends_on:
         certbot:
           condition: service_healthy
       # ...

Set the project's ``.env``:

.. code-block::

   SERVER_HOSTNAME=chat.taram.ca
   RELOAD_SERVICES=nginx
   # GENERATE_DHPARAMS=1   # only projects that consume /etc/letsencrypt/dhparams.pem

``COMPOSE_PROJECT_NAME`` is set automatically by docker compose (defaults to the
project directory name); it's used by ``docker-reload.py`` to find sibling
containers.

Environment contract
--------------------

.. list-table::
   :header-rows: 1
   :widths: 20 10 15 55

   * - Variable
     - Required
     - Default
     - Purpose
   * - ``SERVER_HOSTNAME``
     - yes
     - —
     - Primary cert CN; must match a ``live/<SERVER_HOSTNAME>/`` directory under ``/etc/letsencrypt``
   * - ``COMPOSE_PROJECT_NAME``
     - yes
     - set by compose
     - Container naming prefix used to locate services to reload
   * - ``RELOAD_SERVICES``
     - no
     - ``""``
     - Space-separated compose service names to send SIGHUP after renewal. Empty = no reload
   * - ``GENERATE_DHPARAMS``
     - no
     - ``0``
     - When ``1``, generates ``/etc/letsencrypt/dhparams.pem`` (2048-bit) on first renewal. Only needed by services that reference it (e.g. postfix, dovecot)

What the deploy hook does
-------------------------

On every successful renewal, ``deploy-hook.sh``:

1. (Optional) Generates ``dhparams.pem`` if ``GENERATE_DHPARAMS=1`` and the file is missing.
2. Copies ``live/${SERVER_HOSTNAME}/privkey.pem`` and ``fullchain.pem`` into ``live/privkey.pem`` and ``live/fullchain.pem`` so consumers can reference hostname-agnostic paths.
3. SIGHUPs each service in ``RELOAD_SERVICES`` via the docker socket.

docker-reload.py
----------------

Sends ``POST /containers/<COMPOSE_PROJECT_NAME>-<service>-1/kill?signal=HUP`` over
the docker unix socket. Exit code 0 if all succeed, 1 otherwise.

The certbot container must have ``/var/run/docker.sock`` mounted read-only. This
is wired up in the shared ``compose.yml``.

Self-signed bootstrap
---------------------

``generate-cert.sh`` creates a self-signed cert layout under ``/etc/letsencrypt/``
that mimics Let's Encrypt's directory structure. Useful for dev
(``compose.dev.yml``) where the real ACME flow can't run. Requires
``SERVER_HOSTNAME`` and ``IPV4_NETWORK`` (used as a SAN for internal IP access).

Not wired into the default runtime — mount it only from dev overrides.

Updating
--------

Bump the certbot image version in ``compose.yml``, tag the submodule, then in
each consuming project:

.. code-block:: sh

   git submodule update --remote taracert
