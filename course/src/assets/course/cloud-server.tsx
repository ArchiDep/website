import { G, O, pipe } from '@mobily/ts-belt';
import { signal } from '@preact/signals';
import * as t from 'io-ts';
import { render } from 'preact';
import { JSX } from 'react';
import { ArrowPathIcon } from '../../shared/icons';
import { me } from './session';
import { sample } from 'lodash-es';
import { loadingMessages } from '../../shared/loading';

const studentType = t.readonly(
  t.exact(
    t.type({
      username: t.string,
      usernameConfirmed: t.boolean,
      domain: t.string
    })
  )
);

const cloudServerType = t.readonly(
  t.exact(
    t.type({
      name: t.union([t.string, t.null]),
      username: t.string,
      ipAddress: t.string,
      url: t.string
    })
  )
);

export const cloudServerDataType = t.readonly(
  t.exact(
    t.type({
      student: t.union([studentType, t.null]),
      server: t.union([cloudServerType, t.null]),
      serversEnabled: t.boolean
    })
  )
);

export type Student = t.TypeOf<typeof studentType>;
export type CloudServer = t.TypeOf<typeof cloudServerType>;
export type CloudServerData = t.TypeOf<typeof cloudServerDataType>;

export const cloudServer = signal<CloudServerData | undefined>(undefined);

const cloudServerCardPrimaryProps = {
  cardClass: 'bg-primary text-primary-content',
  titleClass: '!text-primary-content'
};

const cloudServerCardWarningProps = {
  cardClass: 'bg-warning text-warning-content',
  titleClass: '!text-warning-content'
};

type CloudServerInstructionsProps = {
  readonly mode: 'creation' | 'details';
};

function CloudServerInstructions({
  mode
}: CloudServerInstructionsProps): JSX.Element {
  const session = me.value;
  const cloudServerData = cloudServer.value;

  if (session === undefined) {
    return (
      <CloudServerCard {...cloudServerCardWarningProps}>
        <CloudServerLoginInstructions />
      </CloudServerCard>
    );
  } else if (cloudServerData === undefined) {
    return (
      <CloudServerCard>
        <CloudServerLoadingIndicator />
      </CloudServerCard>
    );
  } else if (cloudServerData.student === null) {
    return cloudServerData.server === null ? (
      <CloudServerCard {...cloudServerCardWarningProps}>
        <NoRootCloudServer />
      </CloudServerCard>
    ) : (
      <CloudServerDetails server={cloudServerData.server} />
    );
  }

  const student = cloudServerData.student;
  if (!cloudServerData.serversEnabled) {
    return <StudentCloudServerDisabled mode={mode} />;
  } else if (!student.usernameConfirmed) {
    return <StudentUsernameConfirmationRequired mode={mode} />;
  } else if (cloudServerData.server === null) {
    return mode === 'creation' ? (
      <StudentCloudServerCreationInstructions
        username={student.username}
        domain={student.domain}
      />
    ) : (
      <StudentCloudServerCreationRequired />
    );
  }

  const server = cloudServerData.server;
  return <CloudServerDetails server={server} student={student} />;
}

function CloudServerLoginInstructions(): JSX.Element {
  const loginUrl = `/auth/switch-edu-id/configure?to=${encodeURIComponent(window.location.pathname)}`;

  return (
    <>
      <p>
        Parts of this exercise happen on the cloud server you should have
        created for this course. Log in to see your server's details.
      </p>
      <div className="card-actions justify-end">
        <a className="btn" href={loginUrl}>
          Log in
        </a>
      </div>
    </>
  );
}

function CloudServerLoadingIndicator(): JSX.Element {
  const loadingMessage = sample(loadingMessages);

  return (
    <>
      <p className="flex items-center gap-2">
        <ArrowPathIcon className="size-4 animate-spin" />
        <span>{loadingMessage}...</span>
      </p>
    </>
  );
}

function NoRootCloudServer(): JSX.Element {
  return (
    <>
      <p>
        You are root and either have not registered a server or have too many.
        Make sure only one is active to see its details here.
      </p>
      <div className="card-actions justify-end">
        <a className="btn btn-secondary" href="/app/my-servers">
          My servers
        </a>
      </div>
    </>
  );
}

type StudentUsernameConfirmationRequiredProps = {
  readonly mode: 'creation' | 'details';
};

function StudentUsernameConfirmationRequired(
  props: StudentUsernameConfirmationRequiredProps
): JSX.Element {
  const instructions =
    props.mode === 'creation'
      ? 'You must choose a username before proceeding with this exercise.'
      : 'You must choose your username and create your cloud server before proceeding with this exercise.';

  return (
    <CloudServerCard {...cloudServerCardWarningProps}>
      <p>{instructions}</p>
      <div className="card-actions justify-end">
        <a className="btn btn-secondary" href="/app">
          Let's do that
        </a>
      </div>
    </CloudServerCard>
  );
}

type StudentCloudServerDisabledProps = {
  readonly mode: 'creation' | 'details';
};

function StudentCloudServerDisabled({
  mode
}: StudentCloudServerDisabledProps): JSX.Element {
  const instructions =
    mode === 'creation'
      ? 'This exercise will eventually guide you through creating your own cloud server, but we have not yet reached that point in the course. Please check back later.'
      : 'You will need your own cloud server for this exercise, but we have not yet reached the point where you can create one. Please check back later.';

  return (
    <CloudServerCard>
      <p>{instructions}</p>
    </CloudServerCard>
  );
}

function StudentCloudServerCreationRequired(): JSX.Element {
  return (
    <CloudServerCard {...cloudServerCardPrimaryProps}>
      <p>
        You must create your cloud server before proceeding with this exercise.
      </p>
      <div className="card-actions justify-end">
        <a className="btn btn-secondary" href="/app">
          Create my server
        </a>
      </div>
    </CloudServerCard>
  );
}

type StudentCloudServerCreationInstructionsProps = {
  readonly username: string;
  readonly domain: string;
};

function StudentCloudServerCreationInstructions({
  username,
  domain
}: StudentCloudServerCreationInstructionsProps): JSX.Element {
  return (
    <CloudServerCard {...cloudServerCardPrimaryProps}>
      <p>
        Follow this exercise to create your cloud server. Use the following
        information.
      </p>
      <ul>
        <li>
          <strong>Username:</strong>{' '}
          <span className="font-mono">{username}</span>
        </li>
        <li>
          <strong>Domain:</strong> <span className="font-mono">{domain}</span>
        </li>
        <li>
          <strong>Hostname:</strong>{' '}
          <span className="font-mono">
            {username}.{domain}
          </span>
        </li>
      </ul>
    </CloudServerCard>
  );
}

type CloudServerDetailsProps = {
  readonly server: CloudServer;
  readonly student?: Student;
};

function CloudServerDetails({
  server,
  student
}: CloudServerDetailsProps): JSX.Element {
  const { name, username, ipAddress } = server;
  const domain = student?.domain;

  const instructions = [
    'Here are the connection details for your cloud server',
    pipe(
      O.fromNullable(name),
      O.map(text => ` "${text}"`),
      O.toUndefined
    ),
    '.'
  ]
    .filter(G.isNotNullable)
    .join('');

  return (
    <CloudServerCard {...cloudServerCardPrimaryProps}>
      <p>{instructions}:</p>
      <ul>
        <li>
          <strong>Username:</strong>{' '}
          <span className="font-mono">{username}</span>
        </li>
        <li>
          <strong>IP address:</strong>{' '}
          <span className="font-mono">{ipAddress}</span>
        </li>
        {domain && (
          <li>
            <strong>Hostname:</strong>{' '}
            <span className="font-mono">
              {username}.{domain}
            </span>
          </li>
        )}
      </ul>
    </CloudServerCard>
  );
}

type CloudServerCardProps = {
  readonly cardClass?: string;
  readonly titleClass?: string;
  readonly children: JSX.Element | JSX.Element[] | string;
};

function CloudServerCard(props: CloudServerCardProps): JSX.Element {
  const { children } = props;
  const cardClass = props.cardClass ?? 'bg-info text-info-content';
  const titleClass = props.titleClass ?? '!text-info-content';

  return (
    <div className={`card ${cardClass} w-full`}>
      <div className="card-body">
        <h2 className={`card-title ${titleClass}`}>Cloud server exercise</h2>
        {children}
      </div>
    </div>
  );
}

// function getInstructions(
//   mode: 'creation' | 'details',
//   session?: Session,
//   cloudServerData?: CloudServerData
// ): string | undefined {
//   if (session === undefined) {
//     return "Parts of this exercise happen on the cloud server you should have created for this course. Log in to see your server's details.";
//   } else if (cloudServerData === undefined) {
//     return 'Loading some stuff from somewhere...';
//   } else if (cloudServerData.student === null) {
//     return cloudServerData.server
//       ? undefined
//       : 'You are root and either have not registered a server or have too many damn servers. Make sure only one is active to see its details here.';
//   } else if (!cloudServerData.student.usernameConfirmed) {
//     return mode === 'creation'
//       ? 'You must choose your username before proceeding with this exercise.'
//       : 'You must choose your username and create your cloud server before proceeding with this exercise.';
//   } else if (cloudServerData.server === null && mode === 'creation') {
//     return 'Follow this exercise to create your cloud server.';
//   } else if (cloudServerData.server === null) {
//     return 'You have not created a cloud server yet. Create one to see its details here.';
//   }

//   return undefined;
// }

const element = document.getElementById('cloud-server-data');
if (element) {
  const mode = element.dataset['mode'] === 'details' ? 'details' : 'creation';
  render(<CloudServerInstructions mode={mode} />, element);
}
