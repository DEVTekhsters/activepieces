import { Static, Type } from '@sinclair/typebox'
import { EmailType, PasswordType } from '../../user/user'

export const ValidateAuth = Type.Object({
    email: EmailType,
    password: PasswordType,
})

export type ValidateAuth = Static<typeof ValidateAuth>