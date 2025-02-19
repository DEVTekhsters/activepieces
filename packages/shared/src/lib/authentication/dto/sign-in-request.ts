import { Static, Type } from '@sinclair/typebox'
import { EmailType, PasswordType } from '../../user/user'

export const SignInRequest = Type.Object({
    email: EmailType,
    password: PasswordType,
})
export const AuthenticateInRequest = Type.Object({
    Authentication: EmailType,
    // "device-type": EmailType,
})
export type SignInRequest = Static<typeof SignInRequest>
export type AuthenticateInRequest = Static<typeof AuthenticateInRequest>
